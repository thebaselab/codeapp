---
description: Connect to a self-hosted server and get access to its files and terminal.
---

# Connecting to a remote server (SSH/FTP)

### Set up your remote server

Before using this feature, you'll need to set up a SSH (SFTP) or FTP server on your computer or server. On a Mac, you can do this by enabling Remote Login and full disk access in the `Sharing` section of System Preferences.

![Enabling SSH server on a Mac](<../.gitbook/assets/image (6).png>)

### Set up a new remote in Code App

Open the remote section in the side bar and enter the server's information. Enable `Remember credentials` to save the credentials. Code App will ask for Face ID or Touch ID authentication when you connect to the server again in the future.

![Setting up a new remote](<../.gitbook/assets/image (2).png>)

### Key Authentication

Besides password, SSH keys can also be used to authenticate your server. To do so, enable the `Use key authentication` option and enter your private key.&#x20;

#### Generating key-pairs in Code App

If you don't already have a key-pair, you can generate one with the `ssh-keygen` command in the terminal. You might need to specify the type of keys to generate depending on your server's configuration. For example on macOS Ventura, the default generated RSA key pair is not supported. You can generate a ed25519 key-pair instead by running `ssh-keygen -t ed25519`.

Then, copy the public key to your server's `authorized_keys` file. On macOS, it is located at `~/.ssh/authorized_keys.`

### Finishing up

Congratulations! You can now access the remote server's files and terminal.

{% hint style="info" %}
**Good to know:** Only SSH server allows terminal access
{% endhint %}

![](../.gitbook/assets/image.png)

