# Create the folder (C:\wccit) if it does not already exist
New-Item -ItemType Directory -Path 'C:\wccit' -Force

# Define the UNC source path
$source = "\\ads1\sys\sophossetup.exe"

# Copy the file to the newly ensured folder
Copy-Item -Path $source -Destination 'C:\wccit' -Force

c:\wccit\sophossetup.exe --products=all --quiet
