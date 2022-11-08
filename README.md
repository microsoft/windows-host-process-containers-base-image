# HostProcess container base image

## Overview

This project produces a minimal base image that can be used with [HostProcess containers](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/).

This image *cannot* be used with any other type of Windows container (process isolated, Hyper-V isolated, etc...)

### Benefits

Using this image as a base for HostProcess containers has a few advantages over using other base images for Windows containers including:

- Size - This image is a few KB. Even the smallest official base image (NanoServer) is still a few hundred MB is size.
- OS compatibility - HostProcess containers do not inherit the same [compatibility requirements](https://docs.microsoft.com/virtualization/windowscontainers/deploy-containers/version-compatibility) as Windows server containers and because of this it does not make sense to include all of the runtime / system binaries that make up the different base layers. Using this image allows for a single container image to be used on any Windows Server version which can greatly simplify container build processes.

## Usage

Build your container from `mcr.microsoft.com/oss/kubernetes/windows-host-process-containers-base-image:v1.0.0`.

### Dockerfile example

Create `hello-world.ps1` with the following content:

```powershell
Write-output "Hello World!"
```

and `Dockerfile.windows` with the following content:

```Dockerfile
FROM mcr.microsoft.com/oss/kubernetes/windows-host-process-containers-base-image:v1.0.0

ADD hello-world.ps1 .

ENV PATH="C:\Windows\system32;C:\Windows;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;"
ENTRYPOINT ["powershell.exe", "./hello-world.ps1"]
```

### Build with BuildKit

Containers based on this image cannot currently be built with Docker Desktop.
Instead use BuildKit or other tools.

Example:

#### Create a builder

One time step

```cmd
docker buildx create --name img-builder --use --platform windows/amd64
```

#### Build your image

Use the following command to build and push to a container repository

```cmd
 docker buildx build --platform windows/amd64 --output=type=registry -f {Dockerfile} -t {ImageTag} .
```

### Container Manifests

As mentioned in [Benefits](#benefits) above, HostProcess containers can run on any Windows Server version however
there is currently logic in containerd to only pull Windows container images if the `OSVersion` defined in the
container manifest matches the `OSVersion` of the node.

When building container images from this base image it is recommended to not include this image in a manifest-list
and also not include *any* platform information in the manifest for now.

Please see https://github.com/containerd/containerd/issues/7431 for more information.

## Licensing

Code is the repository is released under the `MIT` [license](/LICENSE).

The container images produced by this repository are distributed under the `CC0` license.

- [CC0 license](/cc0-license.txt)
- [CC0 legacode](/cc0-legalcode.txt)
