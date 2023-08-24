---
description: Use the built-in support for Git to manage your code.
---

# Version Control

{% hint style="warning" %}
Command line git is unavailble because of a licensing issue. Use lg2 or the GUI instead.
{% endhint %}

### Set up your identities

Git uses name and email address identify the author of each commit. Before making a commit, you'll need to set up your identity.

To proceed, go `Settings > Version Control > Identity`.&#x20;

### Set up your credentials

If you are cloning a private repository or pushing changes to a remote, you'll need to set up credentials. To start, enter your credentials at `Settings > Version Control > Authentication`.

#### Password-based Authentication

The easiest way to authenticate in Git is to use password-based authentication. To start, obtain a personal access token from your Git hosting provider. To learn more:

{% embed url="https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token" %}
Creating a personal access token on GitHub
{% endembed %}

{% embed url="https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html" %}
Creating a personal access tokeno on GitLab
{% endembed %}

#### Key-based Authentication

SSH keys can also be used to authenicate in Git. To start, generate a SSH key pair and configure them in your Git hosting provider. To learn more:

{% embed url="https://docs.github.com/en/authentication/connecting-to-github-with-ssh" %}
Connecting to GitHub with SSH keys
{% endembed %}

{% embed url="https://docs.gitlab.com/ee/user/ssh.html" %}
Connecting to GitLab with SSH keys
{% endembed %}

#### Setting up multiple credentials

Code App supports multiple credentials. You can configure a unique credential for each hosting provider by specifying their hostnames during the setup process.

<figure><img src="../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 12.54.27.png" alt=""><figcaption><p>Hostname-based credentials</p></figcaption></figure>

### Cloning a repository

To clone a repository, tap the source control icon in the sidebar and enter its url in the clone repository section.

<figure><img src="../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 12.56.17.png" alt=""><figcaption><p>Cloning a repository</p></figcaption></figure>

### Committing files

Newly added / modified files must be added to the staging area before you can make a commit. To do this, press the plus icon next to the file name.

![Adding a file to staging area](<../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 13.00.09.png>)

You can now enter a commit message in the textfield and press the commit button to commit. You can also use the `command`+`enter` shortcut.

### Pushing to remote

You can push your changes to your hosting provider like GitHub.

![Pushing changes to remote](<../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 13.00.47.png>)

### Branches and tags

To checkout a branch or a tag, tap the branch icon located in the bottom left corner and select one.

![Checkout to a branch](<../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 12.57.21.png>)

### Pull and Fetch

You can also pull or fetch changes from remote. Pull immediately applies the upstream changes to your files. It does so by fast-forwarding the upstream commits if possible or attempting to merge otherwise. On the other hand, fetch does not write changes to your files.

<figure><img src="../.gitbook/assets/Simulator Screenshot - iPad (10th generation) - 2023-08-24 at 12.53.29.png" alt=""><figcaption><p>Pull from a remote</p></figcaption></figure>

To learn more about git pull and fetch:

{% embed url="https://git-scm.com/docs/git-pull" %}

{% embed url="https://git-scm.com/docs/git-fetch" %}

