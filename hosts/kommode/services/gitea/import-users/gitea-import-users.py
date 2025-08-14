import requests
import secrets
import os


EMAIL_DOMAIN = os.getenv('EMAIL_DOMAIN')
if EMAIL_DOMAIN is None:
    EMAIL_DOMAIN = 'pvv.ntnu.no'


API_TOKEN = os.getenv('API_TOKEN')
if API_TOKEN is None:
    raise Exception('API_TOKEN not set')


GITEA_API_URL = os.getenv('GITEA_API_URL')
if GITEA_API_URL is None:
    GITEA_API_URL = 'https://git.pvv.ntnu.no/api/v1'

PASSWD_FILE_PATH = os.getenv('PASSWD_FILE_PATH')
if PASSWD_FILE_PATH is None:
    PASSWD_FILE_PATH = '/tmp/passwd-import'


def gitea_list_all_users() -> dict[str, dict[str, any]] | None:
    r = requests.get(
        GITEA_API_URL + '/admin/users',
        headers={'Authorization': 'token ' + API_TOKEN}
    )

    if r.status_code != 200:
        print('Failed to get users:', r.text)
        return None

    return {user['login']: user for user in r.json()}


def gitea_create_user(username: str, userdata: dict[str, any]) -> bool:
    r = requests.post(
        GITEA_API_URL + '/admin/users',
        json=userdata,
        headers={'Authorization': 'token ' + API_TOKEN},
    )

    if r.status_code != 201:
        print(f'ERR: Failed to create user {username}:', r.text)
        return False

    return True


def gitea_edit_user(username: str, userdata: dict[str, any]) -> bool:
    r = requests.patch(
        GITEA_API_URL + f'/admin/users/{username}',
        json=userdata,
        headers={'Authorization': 'token ' + API_TOKEN},
    )

    if r.status_code != 200:
        print(f'ERR: Failed to update user {username}:', r.text)
        return False

    return True


def gitea_list_teams_for_organization(org: str) -> dict[str, any] | None:
    r = requests.get(
        GITEA_API_URL + f'/orgs/{org}/teams',
        headers={'Authorization': 'token ' + API_TOKEN},
    )

    if r.status_code != 200:
        print(f"ERR: Failed to list teams for {org}:", r.text)
        return None

    return {team['name']: team for team in r.json()}


def gitea_add_user_to_organization_team(username: str, team_id: int) -> bool:
    r = requests.put(
        GITEA_API_URL + f'/teams/{team_id}/members/{username}',
        headers={'Authorization': 'token ' + API_TOKEN},
    )

    if r.status_code != 204:
        print(f'ERR: Failed to add user {username} to org team {team_id}:', r.text)
        return False

    return True


# If a passwd user has one of the following shells,
# it is most likely not a PVV user, but rather a system user.
# Users with these shells should thus be ignored.
BANNED_SHELLS = [
    "/usr/bin/nologin",
    "/usr/sbin/nologin",
    "/sbin/nologin",
    "/bin/false",
    "/bin/msgsh",
]


# Reads out a passwd-file line for line, and filters out
# real PVV users (as opposed to system users meant for daemons and such)
def passwd_file_parser(passwd_path):
    with open(passwd_path, 'r') as f:
        for line in f.readlines():
            uid = int(line.split(':')[2])
            if uid < 1000:
                continue

            shell = line.split(':')[-1]
            if shell in BANNED_SHELLS:
                continue

            username = line.split(':')[0]
            name = line.split(':')[4].split(',')[0]
            yield (username, name)


# This function either creates a new user in gitea
# and fills it out with some default information if
# it does not exist, or ensures that the default information
# is correct if the user already exists. All user information
# (including non-default fields) is pulled from gitea and added
# to the `existing_users` dict
def add_or_patch_gitea_user(
    username: str,
    name: str,
    existing_users: dict[str, dict[str, any]],
) -> None:
    user = {
        "full_name": name,
        "username": username,
        "login_name": username,
        "source_id": 1,  # 1 = SMTP
    }

    if username not in existing_users:
        user["password"] = secrets.token_urlsafe(32)
        user["must_change_password"] = False
        user["visibility"] = "private"
        user["email"] = username + '@' + EMAIL_DOMAIN

        if not gitea_create_user(username, user):
            return

        print('Created user', username)
        existing_users[username] = user

    else:
        user["visibility"] = existing_users[username]["visibility"]

        if not gitea_edit_user(username, user):
            return

        print('Updated user', username)


# This function adds a user to a gitea team (part of organization)
# if the user is not already part of said team.
def ensure_gitea_user_is_part_of_team(
    username: str,
    org: str,
    team_name: str,
) -> None:
    teams = gitea_list_teams_for_organization(org)

    if teams is None:
        return

    if team_name not in teams:
        print(f'ERR: could not find team "{team_name}" in organization "{org}"')

    gitea_add_user_to_organization_team(username, teams[team_name]['id'])

    print(f'User {username} is now part of {org}/{team_name}')


# List of teams that all users should be part of by default
COMMON_USER_TEAMS = [
    ("Projects", "Members"),
    ("Grzegorz", "Members"),
    ("Kurs", "Members"),
]


def main():
    existing_users = gitea_list_all_users()
    if existing_users is None:
        exit(1)

    print(f"Reading passwd entries from {PASSWD_FILE_PATH}")
    for username, name in passwd_file_parser(PASSWD_FILE_PATH):
        print(f"Processing {username}")
        add_or_patch_gitea_user(username, name, existing_users)
        for org, team_name in COMMON_USER_TEAMS:
            ensure_gitea_user_is_part_of_team(username, org, team_name)
        print()


if __name__ == '__main__':
    main()
