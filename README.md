# Church av project

This project contains normalized textfiles for hymnals that can be converted using scripts to formats compatible with relevant projection software.
The projection software am using is Freeshow however support for other's shall be added later

## Usage 

### Windows
If on a Microsoft Windows system, to convert the textfiles in raw_text* folders to a format that is compatible and easier to use with freeshow,
open / run powershell as administrator
run 
```
cd C:\Users\<your_user>\
```
The command above changes the directory to your users directory where you can then create a directory that will house your projects. You can use
```
md -Force .\Projects\church_av
```
Once the dirctory is created we can change into the directory and begin 
```
cd .\Projects\church_av
```
While in the folder `church_av`, clone this repository using the command below.
(requires git to be installed. use command `winget install --id Git.Git -e --source winget`, to install git, and confirm installation using `git --version` command)
```
git clone https://github.com/its-kamash/church_av
```
or download the zip file for and extract it in the `church_av` directory 

While in the `church_av` directory, make a directory that will house your hymnals that will be formated to textfile format that freeshow accepts
e.g the raw_text_en folder contains the SDA Hymnal in english. The process for converting it would look like this
```
md -Force .\Freeshow\sdah_en
```
This will create a clean directory structure. Then before using the scripts first we must make sure powershell will allow them to be executable.
```
Unblock-File .\convert_to_freeshow.ps1
```
then finaly we can use the script as follows
```
.\convert_to_freeshow.ps1 -InputFolder ".\raw_text_en" -OutputFolder ".\Freeshow\sdah_en"
```
With that the folder sdah_en will be ready to be imported by Freeshow.
The steps are the same for any subsequent raw_text* folder available. Only add new directory in the freeshow directory e.g while in the `church_av` folder still, do `md .\Freeshow\sdah_sw`
then for the script modify the command to adjust for the new directory in both the source i.e InputFolder and destination i.e OutputFolder 

### Linux

If using linux, first refer to your distro's package manager on how to install git. An example like debian and debian derived distros might use 
```
sudo apt install git
```
NB – This might require root priviledges to do on linux so ensure you have proper priviledges.

Open the terminal then the next step would to prepare the environment by changing to your users home directory. in the terminal do
```
cd ~
```
Then prepare the directory structure and change into the `church_av` directory
```
mkdir -p ./Projects/church_av && cd Projects\church_av
```
Clone the repository
```
git clone https://github.com/its-kamash/church_av
```
Make the destination directories 
```
mkdir -p ./Freeshow/sdah_en
```
Then we need to ensure the script is executable(also requires root user priviledges to do)
```
sudo chmod +x ./convert_to_freeshow.sh
```
The script can then be used to do the conversion
```
./convert_to_freeshow.sh -i ./raw_text_en -o ./FreeShow/sdah_en
```
