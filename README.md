# HostProcess container base image

## Overview

This project produces a minimal base image that can be used with [HostProcess containers](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/).

This image *cannot* be used with any other type of Windows container (process isolated, Hyper-V isolated, etc...)

### Benefits

Using this image as a base for HostProcess containers has a few advantages over using other base images for Windows containers including:

- Size - This image is a few KB. Even the smallest official base image (NanoServer) is still a few hundred MB is size.
- OS compatibility - HostProcess containers do not inherit the same [compatibility requirements](https://learn.microsoft.com/virtualization/windowscontainers/deploy-containers/version-compatibility) as Windows Server containers. This image omits runtime / system binaries, allowing an image for a given architecture to be reused across Windows host versions that support the workload and its container runtime.

## Building the base image

Run [New-HostProcessBaseImage.ps1](./New-HostProcessBaseImage.ps1) from the repository root with PowerShell and `tar.exe` available:

```powershell
# AMD64 is the default, preserving existing builds.
.\New-HostProcessBaseImage.ps1

# Generate a Windows ARM64 image.
.\New-HostProcessBaseImage.ps1 -Architecture arm64
```

The `-Architecture` parameter accepts `amd64` and `arm64`. It sets the architecture in both the image configuration and legacy layer metadata; the operating system remains `windows`.

The image archive is written to `build\windows-host-process-containers-base-image.tar`, and its configuration hash is written to `build\image-id.txt`. Each run replaces the `build` directory, so save or import an archive before generating another architecture.

The layer contains no executable binaries, so either variant can be generated on an AMD64 build host. CI generates and checks both variants in separate jobs. Native binaries added by downstream images must target the selected Windows architecture.

ARM64 image generation does not establish end-to-end Windows ARM64 HostProcess support. Validate the target Windows version, containerd/hcsshim stack, Kubernetes components, and image pull, unpacking, and execution on an actual ARM64 host.

## Usage

The examples below use `mcr.microsoft.com/oss/kubernetes/windows-host-process-containers-base-image:v1.0.0`.
Use a published base image matching your target architecture, or publish an image generated as described above.
Generating an ARM64 archive locally does not add ARM64 support to an existing published tag.

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

Use a builder that supports the target Windows platform and this minimal base image.
[BuildKit's Windows container support](https://docs.docker.com/build/buildkit/#buildkit-on-windows) is experimental; ARM64 binaries are available but are not officially tested.
Do not assume Docker Desktop's default builder supports this image. Configure a compatible builder explicitly, following the BuildKit setup instructions, which also describe Docker Desktop integration.

Example:

#### Create a builder

Connect to a BuildKit daemon configured for the target Windows platform. Replace `{BuildKitEndpoint}` with its endpoint:

```cmd
docker buildx create --name img-builder --driver remote --use {BuildKitEndpoint}
docker buildx inspect --bootstrap
```

Confirm that the builder reports the required platform. Setting `--platform` alone does not add platform support to a builder.

#### Build your image

Use the following command to build and push to a container repository

```cmd
docker buildx build --platform windows/amd64 --output=type=registry -f {Dockerfile} -t {ImageTag} .
```

For ARM64, first select a `windows/arm64` base image in the Dockerfile and a builder supporting that platform, then use:

```cmd
docker buildx build --platform windows/arm64 --output=type=registry -f {Dockerfile} -t {ImageTag} .
```

### Container Manifests

As mentioned in [Benefits](#benefits), HostProcess workloads do not inherit the usual Windows Server container image/host OS-version matching requirements.

Containerd 1.7 and later include [a fallback for Windows platforms without an OS version](https://github.com/containerd/containerd/pull/8101), resolving [containerd/containerd#7431](https://github.com/containerd/containerd/issues/7431).
For these runtimes, a manifest list can contain Windows entries with `os: windows` and the appropriate `architecture` (`amd64` or `arm64`), without an `os.version` field.
Omit `os.version` from the Windows platform descriptors for these HostProcess images to avoid imposing a host-version match; retain the correct OS and architecture metadata.

Older containerd releases without this fix may reject such manifest lists. For those deployments, use architecture-specific single-image tags instead and verify image selection on the target runtime.

## Licensing

Code in the repository is released under the `MIT` [license](./LICENSE).

The container images produced by this repository are distributed under the `CC0` license.

- [CC0 license](./cc0-license.txt)
- [CC0 legal code](./cc0-legalcode.txt)
