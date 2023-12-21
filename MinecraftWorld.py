import os
import subprocess
import time
from datetime import datetime

# GitHub App details
APP_ID = "722562"
PRIVATE_KEY_PATH = "C:/Users/Jon/Desktop/Minecraft-World-/minecraft-world-autouploader.2023-12-19.private-key.pem"
REPO_NAME = "Minecraft-World-"

# Local Minecraft server directory
SERVER_DIR = "C:/Users/Jon/Desktop/Minecraft-World-/Minecraft Server"
SERVER_JAR = "server.jar"

def run_command(command, cwd=None, input_data=None):
    """Run a command and return the output."""
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, input=input_data, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return None

def commit_and_push_changes():
    # Commit and push changes to the local Git repository
    run_command(["git", "add", "."], cwd=SERVER_DIR)
    run_command(["git", "commit", "-m", f"Automated commit - {datetime.now()}"], cwd=SERVER_DIR)
    run_command(["git", "push"], cwd=SERVER_DIR)

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

def main():
    server_process = None

    try:
        while True:
            # Check if the Minecraft server process is running
            if server_process is None or server_process.poll() is not None:
                print("Minecraft server closed. Performing actions...")
                commit_and_push_changes()
                push_to_github()
                server_process = None  # Reset server process

            # If the server process is not set or has terminated, start it
            if server_process is None:
                print("Starting Minecraft server...")
                server_process = subprocess.Popen(["java", "-jar", SERVER_JAR], cwd=SERVER_DIR)

            # Check every minute (adjust as needed)
            time.sleep(60)

    except KeyboardInterrupt:
        # Handle manual termination and push changes
        commit_and_push_changes()
        push_to_github()

        # Terminate the Minecraft server process if it's still running
        if server_process is not None and server_process.poll() is None:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        # Ensure changes are pushed before exiting
        commit_and_push_changes()
        push_to_github()
