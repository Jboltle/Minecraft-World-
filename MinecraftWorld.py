import os
import subprocess
import time
from datetime import datetime

# GitHub App details
APP_ID = "722562"
CLIENT_ID = "Iv1.8343edfd38855a86"
PRIVATE_KEY_PATH = "C:/Users/Jon/Desktop/Minecraft-World-/minecraft-world-autouploader.2023-12-19.private-key.pem"
REPO_NAME = "Minecraft-World-"

# Local Minecraft server directory
SERVER_DIR = "C:/Users/Jon/Desktop/Minecraft-World-"

def commit_and_push_changes():
    # Commit and push changes to the local Git repository
    subprocess.run(["git", "-C", SERVER_DIR, "add", "."])
    subprocess.run(["git", "-C", SERVER_DIR, "commit", "-m", "Automated commit - {}".format(datetime.now())])
    subprocess.run(["git", "-C", SERVER_DIR, "push"])

def push_to_github():
    # Authenticate with GitHub App using the private key
    gh_auth_command = ["gh", "auth", "login", "--with-token"]
    gh_upload_command = ["gh", "repo", "upload", "--repo", REPO_NAME, "--branch", "main"]

    try:
        with open(PRIVATE_KEY_PATH, "r") as private_key_file:
            private_key_content = private_key_file.read()

        # Run GitHub authentication
        run_command(gh_auth_command, cwd=SERVER_DIR, input_data=private_key_content)

        # Clone repository, copy files, and upload to GitHub
        run_command(["gh", "repo", "clone", REPO_NAME], cwd=SERVER_DIR)
        run_command(["cp", "-r", f"{SERVER_DIR}/*", REPO_NAME], cwd=SERVER_DIR)
        run_command(gh_upload_command, cwd=REPO_NAME)

    except FileNotFoundError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

def run_command(command, cwd=None, input_data=None):
    """Run a command and return the output."""
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, input=input_data, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return None


def main():
    try:
        while True:
            # Commit and push changes every hour
            commit_and_push_changes()
            push_to_github()
            time.sleep(3600)  # Sleep for one hour
            print(f"Sleeping for 1 hour")
    except KeyboardInterrupt:
        # Handle manual termination and push changes
        commit_and_push_changes()
        push_to_github()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        # Ensure changes are pushed before exiting
        commit_and_push_changes()
        push_to_github()
