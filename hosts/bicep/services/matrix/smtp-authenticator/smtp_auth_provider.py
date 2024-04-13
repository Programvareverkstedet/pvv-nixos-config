from typing import Awaitable, Callable, Optional, Tuple

from smtplib import SMTP_SSL as SMTP

import synapse
from synapse import module_api

import re

import logging
logger = logging.getLogger(__name__)

class SMTPAuthProvider:
    def __init__(self, config: dict, api: module_api):
        self.api = api

        self.config = config

        api.register_password_auth_provider_callbacks(
            auth_checkers={
                ("m.login.password", ("password",)): self.check_pass,
            },
        )

    async def check_pass(
        self,
        username: str,
        login_type: str,
        login_dict: "synapse.module_api.JsonDict",
    ):
        if login_type != "m.login.password":
            return None

        # Convert `@username:server` to `username`
        match = re.match(r'^@([\da-z\-\.=_\/\+]+):[\w\d\.:\[\]]+$', username)
        username = match.group(1) if match else username

        result = False
        with SMTP(self.config["smtp_host"]) as smtp:
            password = login_dict.get("password")
            try:
                smtp.login(username, password)
                result = True
            except:
                return None

        if result == True:
            userid = self.api.get_qualified_user_id(username)

            userid = await self.api.check_user_exists(userid)
            if not userid:
                logger.info(f"user did not exist, registering {username}")
                userid = await self.api.register_user(username)
                logger.info(f"registered userid: {userid}")
            return (userid, None)
        else:
            logger.info("returning None")
            return None
