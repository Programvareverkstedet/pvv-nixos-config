use nix::{
    errno::Errno,
    fcntl::{FcntlArg, OFlag, fcntl, open},
    sys::{
        epoll::{Epoll, EpollCreateFlags, EpollEvent, EpollFlags, EpollTimeout},
        stat::Mode,
    },
    unistd::{User, getegid, geteuid, read, setegid, seteuid, write},
};
use std::{
    collections::VecDeque,
    os::fd::{AsFd, BorrowedFd, OwnedFd},
    path::PathBuf,
    process::exit,
};
use time::{OffsetDateTime, format_description};

const READ_BUFFER_SIZE: usize = 8 * 1024;

#[derive(Debug, Clone, Copy)]
enum LogMode {
    Access,
    Error,
}

fn main() -> Result<(), String> {
    let log_mode = match std::env::args().nth(1).as_deref() {
        Some("access") => LogMode::Access,
        Some("error") => LogMode::Error,
        Some(other) => {
            return Err(format!(
                "invalid log mode `{other}`; expected `access` or `error`"
            ));
        }
        None => return Err("missing log mode argument; expected `access` or `error`".to_string()),
    };

    let tee_file = match log_mode {
        LogMode::Access => None,
        LogMode::Error => Some(
            open(
                &PathBuf::from("/var/log/httpd/error.log"),
                OFlag::O_WRONLY | OFlag::O_APPEND | OFlag::O_CREAT | OFlag::O_CLOEXEC,
                Mode::S_IRUSR | Mode::S_IWUSR,
            )
            .map_err(|error| format!("failed to open error log for teeing: {error}"))?,
        ),
    };

    let stdin = std::io::stdin();

    fcntl(stdin.as_fd(), FcntlArg::F_GETFL)
        .map(OFlag::from_bits_retain)
        .map(|flags| FcntlArg::F_SETFL(flags | OFlag::O_NONBLOCK))
        .and_then(|flags| fcntl(stdin.as_fd(), flags))
        .map_err(|error| format!("failed to make stdin nonblocking: {error}"))?;

    let epoll = Epoll::new(EpollCreateFlags::EPOLL_CLOEXEC)
        .map_err(|error| format!("failed to create epoll instance: {error}"))?;

    epoll
        .add(
            stdin.as_fd(),
            EpollEvent::new(
                EpollFlags::EPOLLIN | EpollFlags::EPOLLERR | EpollFlags::EPOLLHUP,
                0,
            ),
        )
        .map_err(|error| format!("failed to register stdin with epoll: {error}"))?;

    if let Err(error) = event_loop(log_mode, epoll, stdin.as_fd(), tee_file) {
        eprintln!("Error: {error}");
        exit(1);
    }

    Ok(())
}

fn event_loop(
    log_mode: LogMode,
    epoll: Epoll,
    stdin_fd: BorrowedFd<'_>,
    mut tee_file: Option<OwnedFd>,
) -> Result<(), String> {
    let mut events = [EpollEvent::empty(); 1];
    let mut pending = VecDeque::new();

    loop {
        let ready = loop {
            match epoll.wait(&mut events, EpollTimeout::NONE) {
                Ok(ready) => break ready,
                Err(Errno::EINTR) => continue,
                Err(error) => {
                    return Err(format!("epoll wait failed: {error}"));
                }
            }
        };

        if ready == 0 {
            continue;
        }

        let mut scratch = [0u8; READ_BUFFER_SIZE];

        let eof = loop {
            match read(stdin_fd, &mut scratch) {
                Ok(0) => break true,
                Ok(read_bytes) => pending.extend(scratch[..read_bytes].iter().copied()),
                Err(Errno::EINTR) => continue,
                Err(Errno::EAGAIN) => break false,
                Err(error) => {
                    return Err(format!("failed to read from stdin: {error}"));
                }
            }
        };

        while let Some(newline_index) = pending.iter().position(|byte| *byte == b'\n') {
            let line = pending.make_contiguous();
            process_line(log_mode, &line[..=newline_index], &mut tee_file)?;
            pending.drain(..=newline_index);
        }

        if eof {
            if !pending.is_empty() {
                process_line(log_mode, pending.make_contiguous(), &mut tee_file)?;
                pending.clear();
            }
            return Ok(());
        }
    }
}

fn process_line(
    log_mode: LogMode,
    line: &[u8],
    tee_file: &mut Option<OwnedFd>,
) -> Result<(), String> {
    if let Some(tee_file) = tee_file.as_ref() {
        write_all_fd(tee_file, line).map_err(|error| {
            format!("failed to append to APACHE_LOG_PROCESSOR_TEE_FILE: {error}")
        })?;
    }

    if let Some(user) =
        parse_username_from_line(line).and_then(|name| User::from_name(name).ok().flatten())
    {
        let identity = EffectiveIdentity::switch_to(&user).map_err(|error| {
            format!(
                "failed to switch effective identity to {} (uid {}, gid {}): {error}",
                user.name, user.uid, user.gid
            )
        })?;

        let result: Result<(), String> = (|| {
            let dir = user.dir.join("nobackup/weblogs");

            if !dir.is_dir() {
                return Err(format!(
                    "logs directory {} does not exist for user {}",
                    dir.display(),
                    user.name
                ));
            }

            let now = OffsetDateTime::now_local()
                .unwrap_or_else(|_| OffsetDateTime::now_utc())
                .format(&format_description::parse("[year]-[month]-[day]").unwrap())
                .map_err(|error| {
                    format!("failed to format current date for log file name: {error}")
                })?;

            let logfile = dir.join(match log_mode {
                LogMode::Access => format!("access-{now}.log"),
                LogMode::Error => format!("error-{now}.log"),
            });

            let fd = open(
                &logfile,
                OFlag::O_WRONLY | OFlag::O_APPEND | OFlag::O_CREAT | OFlag::O_CLOEXEC,
                Mode::S_IRUSR
                    | Mode::S_IWUSR
                    | Mode::S_IRGRP
                    | Mode::S_IROTH
                    | Mode::S_IWGRP
                    | Mode::S_IWOTH,
            )
            .map_err(|error| format!("failed to open log file for user {}: {error}", user.name))?;

            write_all_fd(fd.as_fd(), line).map_err(|error| {
                format!(
                    "failed to append to log file for user {}: {error}",
                    user.name
                )
            })?;

            Ok(())
        })();

        if let Err(error) = result {
            eprintln!("Error processing log line for user {}: {error}", user.name);
        }

        identity.restore().map_err(|error| {
            format!(
                "failed to restore original effective identity after handling {}: {error}",
                user.name
            )
        })?;
    }

    Ok(())
}

fn parse_username_from_line(line: &[u8]) -> Option<&str> {
    line.splitn(8, |&b| b == b' ')
        .nth(6)
        .and_then(|path| {
            path.strip_prefix(b"/~")
                .and_then(|rest| rest.split(|&b| b == b'/').next())
        })
        .or_else(|| {
            line.windows(b"/home/pvv/".len())
                .enumerate()
                .find_map(|(start, window)| {
                    (window == b"/home/pvv/")
                        .then_some(start + b"/home/pvv/".len())
                        .and_then(|start| line.get(start..))
                        .filter(|rest| rest.get(1) == Some(&b'/'))
                        .and_then(|rest| rest.get(2..))
                        .and_then(|rest| rest.split(|&b| b == b'/').next())
                })
        })
        .filter(|segment| !segment.is_empty())
        .and_then(|segment| std::str::from_utf8(segment).ok())
}

fn write_all_fd<Fd: AsFd>(fd: Fd, mut buffer: &[u8]) -> nix::Result<()> {
    while !buffer.is_empty() {
        match write(fd.as_fd(), buffer) {
            Ok(0) => return Err(Errno::EIO),
            Ok(written) => buffer = &buffer[written..],
            Err(Errno::EINTR) => continue,
            Err(error) => return Err(error),
        }
    }

    Ok(())
}

struct EffectiveIdentity {
    saved_euid: nix::unistd::Uid,
    saved_egid: nix::unistd::Gid,
    restored: bool,
}

impl EffectiveIdentity {
    fn switch_to(user: &User) -> nix::Result<Self> {
        let guard = Self {
            saved_euid: geteuid(),
            saved_egid: getegid(),
            restored: false,
        };

        setegid(user.gid)?;
        if let Err(error) = seteuid(user.uid) {
            let _ = setegid(guard.saved_egid);
            return Err(error);
        }

        Ok(guard)
    }

    fn restore(mut self) -> nix::Result<()> {
        let restore_uid = seteuid(self.saved_euid);
        let restore_gid = setegid(self.saved_egid);
        self.restored = true;

        restore_uid?;
        restore_gid?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_user_from_access_log() {
        let inputs = [(
            "1.2.3.4 - - [25/May/2026:10:07:24 +0200] \"GET /~oysteikt/ HTTP/2.0\" 200 3708",
            "oysteikt",
        )];

        for (line, expected_user) in inputs {
            let parsed_user = parse_username_from_line(line.as_bytes());
            assert_eq!(
                parsed_user,
                Some(expected_user),
                "Failed to parse user from line: {line}"
            );
        }
    }

    #[test]
    fn test_parse_user_from_error_log() {
        let inputs = [(
            "[Sat May 09 20:45:21.480016 2026] [authz_core:error] [pid 3555:tid 3617] [remote 1::2:42000] AH01630: client denied by server configuration: /home/pvv/d/oysteikt/web-docs/.git",
            "oysteikt",
        )];

        for (line, expected_user) in inputs {
            let parsed_user = parse_username_from_line(line.as_bytes());
            assert_eq!(
                parsed_user,
                Some(expected_user),
                "Failed to parse user from line: {line}"
            );
        }
    }
}
