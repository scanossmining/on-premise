# SCANOSS On-Premise: Knowledge Base Updates

# Introduction

This document aims to guide users through the process of updating the SCANOSS knowledge base for on-premise environments.

This repository contains all necessary scripts for updating the SCANOSS knowledge base, from downloading and importing the update to verifying it's working as intended.

# Contents of this directory

- [kb-update.sh](./kb-update.sh): bash script for updating the SCANOSS knowledge base

# Step-by-step

## Preparing the environment

After receiving the email from our Sales team containing this repository's contents as well as the credentials to access our SFTP server and updates directory path, you will have everything needed to update the SCANOSS knowledge base.

Make sure the scripts have execution permissions, if not add them with the following command:

```
chmod -R +x update/*.sh
```

Another thing to keep in my mind is that this script needs to be run as root, either using ```sudo``` or directly as the root user.

## Updating the SCANOSS KB with kb-update.sh

The script you need to run for updating the SCANOSS knowledge base is ``kb-update.sh``, this script will take care of downloading the update from the SCANOSS SFTP server and importing the update into the existing ldb.

To run the command type:

```
./update-kb.sh
```

You will be prompted with the following menu:

```
Starting knowledge base update script...

Knowledge Base Update Menu
------------------------
1) Start knowledge base update
2) Quit

Enter your choice [1-2]:
```

The first option will give you the option to download and/or import the knowledge base update. If you are downloading the knowledge base update from the server running SCANOSS, make sure to run both actions when prompted (the distinction between download and import may be useful for users downloading the update through a jumpbox, for example).

> **_Note:_**  During the script, you will also be prompted for setting up download and import paths. We recommend using the default values for most options, this will make it easier for debugging if needed.

### Configuration during script execution

During the execution of this script you will be prompted for the knowledge base update version to download, download location and existing ldb location during the import process.

> **_Note:_**  We recommend executing this script in a tmux session, due to the duration of the download and/or import process. If you choose to execute the script in a normal session make sure the script doesn't get interrupted during the import or you may cause corruption in the existing ldb.

### Verifying import process

After importing the knowledge base update, you can verify the installation by scanning the YY.MM_test_file.wfp and YY.MM_test_snippet.wfp files contained in the knowledge base update directory. For this you can use your tool of choice (e.g. scanoss-py).

If the file and snippet wfp return their appropiate matches, the update/import process was successful.

# Support

If you encounter any issues with the scripts or have any questions, feel free to get in touch with us through the channels provided by the sales team.
