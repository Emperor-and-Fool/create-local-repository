# create-local-repository

Simple bash script to ease the steps to create a working repository of .deb files that auto-update when a new file is added.

1. Place the two scripts anywhere preferably in your home-folder
2. You can run each script separately using the well known ./script.sh command
3. You can use ./create-local-repo.sh to automatically use the signed-repo-script.sh script sequentially.

When I looked around to find out if it was easy to create a simple software directory on my local laptop and PC, without any aim to be available via http, I found like with many things, there are a lot of people talking about a lot of things with many options and various ways to achieve several things. Once I discovered the error-message-less way to do what I had in mind, I had a valid way to add valid .deb downloads to the automatic update sequence. And I had learned a thing or two.

For a big part these are my first steps in scripting. I have no clue where I will end up developing. But showing people how to do things asks to at least know some things myself. And what I hope is I do not only share the Bash language in a helpful way, but also the human language for anyone who wants to understand more about apt, gpg, pgp, clearsigning, detached signing, armoring or dearmoring encrypted keys and key-pairs. To start with through the terminal output, and also through the comments in the scripts where possible.  
