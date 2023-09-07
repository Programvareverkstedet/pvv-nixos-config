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

BANNED_SHELLS = [
    "/usr/bin/nologin",
    "/usr/sbin/nologin",
    "/sbin/nologin",
    "/bin/false",
    "/bin/msgsh",
]

existing_users = {}


# This function should only ever be called when adding users
# from the passwd file
def add_user(username, name):
    user = {
            "full_name": name,
            "username": username,
            "login_name": username,
            "visibility": "public",
            "source_id": 1,  # 1 = SMTP
    }

    if username not in existing_users:
        user["password"] = secrets.token_urlsafe(32)
        user["must_change_password"] = False
        user["visibility"] = "private"
        user["email"] = username + '@' + EMAIL_DOMAIN

        r = requests.post(GITEA_API_URL + '/admin/users', json=user,
                          headers={'Authorization': 'token ' + API_TOKEN})
        if r.status_code != 201:
            print('ERR: Failed to create user ' + username + ': ' + r.text)
            return

        print('Created user ' + username)
        existing_users[username] = user

    else:
        r = requests.patch(GITEA_API_URL + f'/admin/users/{username}',
                           json=user,
                           headers={'Authorization': 'token ' + API_TOKEN})
        if r.status_code != 200:
            print('ERR: Failed to update user ' + username + ': ' + r.text)
            return

        print('Updated user ' + username)


def main():
    # Fetch existing users
    r = requests.get(GITEA_API_URL + '/admin/users',
                     headers={'Authorization': 'token ' + API_TOKEN})

    if r.status_code != 200:
        raise Exception('Failed to get users: ' + r.text)

    for user in r.json():
        existing_users[user['login']] = user

    # Read the file, add each user
    with open("/tmp/passwd-import", 'r') as f:
        for line in f.readlines():
            uid = int(line.split(':')[2])
            if uid < 1000:
                continue

            shell = line.split(':')[-1]
            if shell in BANNED_SHELLS:
                continue

            username = line.split(':')[0]
            name = line.split(':')[4].split(',')[0]

            add_user(username, name)


if __name__ == '__main__':
    main()
