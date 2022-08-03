Remove-Item -Path "build" -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "build" | Out-Null
New-Item -ItemType Directory -Path "build\layer" | Out-Null

# Create the files that ProcessBaseLayer on Windows validates when unpackage images.
# These files can be empty, they just need to exist at specific paths.
New-Item -ItemType Directory -Path "build\layer\Files\Windows\System32\config" -Force | Out-Null
foreach ($f in @('DEFAULT', 'SAM', 'SECURITY', 'SOFTWARE', 'SYSTEM')) {
    New-Item -ItemType File -Name $f -Path "build\layer\Files\Windows\System32\config" | Out-Null
}

# Add CC0 license to image.
Copy-Item -Path "cc0-license.txt" -Destination "build\layer\Files\License.txt"
Copy-item -Path "cc0-legalcode.txt" -Destination "build\layer\Files\cc0-legalcode.txt"

# Create layer.tar
Push-Location build\layer
tar.exe -cf layer.tar Files
Pop-Location

# Get hash of layer.tar
$layerHash = (Get-FileHash -Algorithm SHA256 "build\layer\layer.tar").Hash.ToLower()
Write-Output "layer.tar hash: $layerHash"

# Add json and VERSION files for layer
New-Item -ItemType Directory -Path "build\image\${layerhash}" | Out-Null
"1.0" | Out-File -FilePath "build\image\${layerHash}\VERSION" -Encoding ascii
Copy-Item -Path  "build\layer\layer.tar" -Destination "build\image\${layerHash}\layer.tar"

$now = [DateTime]::UtcNow.ToString("o")
@"
{
    "id": "${layerHash}",
    "created": "${now}",
    "container_config": {
        "Hostname": "",
        "Domainname": "",
        "User": "",
        "AttachStdin": false,
        "AttachStdout": false,
        "AttachStderr": false,
        "Tty": false,
        "OpenStdin": false,
        "StdinOnce": false,
        "Env": null,
        "Cmd": null,
        "Image": "",
        "Volumes": null,
        "WorkingDir": "",
        "Entrypoint": null,
        "OnBuild": null,
        "Labels": null
    },
    "config": {
        "Hostname": "",
        "Domainname": "",
        "User": "ContainerUser",
        "AttachStdin": false,
        "AttachStdout": false,
        "AttachStderr": false,
        "Tty": false,
        "OpenStdin": false,
        "StdinOnce": false,
        "Env": null,
        "Cmd": [
            "c:\\windows\\system32\\cmd.exe"
        ],
        "Image": "",
        "Volumes": null,
        "WorkingDir": "",
        "Entrypoint": null,
        "OnBuild": null,
        "Labels": null
    },
    "architecture": "amd64",
    "os": "windows"
}
"@ | Out-File -FilePath "build\image\${layerHash}\json" -Encoding ascii


# Create the image config and manifest files
@"
{
    "architecture": "amd64",
    "config": {
        "Hostname": "",
        "Domainname": "",
        "User": "",
        "AttachStdin": false,
        "AttachStdout": false,
        "AttachStderr": false,
        "Tty": false,
        "OpenStdin": false,
        "StdinOnce": false,
        "Env": null,
        "Cmd": [
            "c:\\windows\\system32\\cmd.exe"
        ],
        "Image": "",
        "Volumes": null,
        "WorkingDir": "",
        "Entrypoint": null,
        "OnBuild": null,
        "Labels": null
    },
    "created": "${now}",
    "history": [
        {
            "created": "${now}"
        }
    ],
    "os": "windows",
    "os.version": "10.0.17763.1",
    "rootfs": {
        "type": "layers",
        "diff_ids": [
            "sha256:${layerHash}"
        ]
    }
}
"@ | Out-File -FilePath "build\image\config.json" -Encoding ascii
$configHash = (Get-FileHash -Algorithm SHA256 "build\image\config.json").Hash.ToLower()
Move-Item -Path "build\image\config.json" -Destination "build\image\${configHash}.json"

@"
[
    {
        "Config": "${configHash}.json",
        "Layers": [
            "${layerHash}/layer.tar"
        ]
    }
]
"@ | Out-File  -FilePath "build\image\manifest.json" -Encoding ascii

# Tar the image
tar.exe  -cf "build\host-process-scratch.tar" -C "build\image" .

# Output a file with the image hash so we can import/push the image from CI
"${configHash}" | Out-File -FilePath "build\image-id.txt" -Encoding ascii  -NoNewline
