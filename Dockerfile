# Jenkins with Android SDK
# Supports running Android builds (compile, lint, unit tests, instrumentation via emulator, etc.)

FROM jenkins/jenkins:latest

# Switch to root to install system dependencies
USER root

# ── System dependencies ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    wget \
    git \
    ca-certificates
    # Required for 32-bit Android toolchain binaries
    # lib32z1 \
    # lib32stdc++6 \
    # Required for emulator / KVM acceleration (optional but useful)
    # cpu-checker \
    # qemu-kvm \
    # libvirt-daemon-system

# ── Java (LTS) ───────────────────────────────────────────────────────────────
# Jenkins ships with its own JRE, but Android tooling needs a full JDK on PATH.
# Adjust the version to match your minSdk / AGP requirements (17 recommended for AGP 8+).
RUN apt-get install -y --no-install-recommends \
    openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# ── Android SDK versions to install ──────────────────────────────────────────
# Adjust these ARGs to match your project's compileSdk / buildToolsVersion / NDK needs.
ARG ANDROID_COMPILE_SDK=37.0
ARG ANDROID_BUILD_TOOLS=37.0.0
ARG ANDROID_SDK_TOOLS_VERSION=11076708
ARG ANDROID_NDK_VERSION=26.1.10909125 # Optional – remove the NDK install block if unused

# ── Environment variables ─────────────────────────────────────────────────────
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    # cmdline-tools 'latest' symlink lives here after install
    PATH="${PATH}:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator"

# ── Download & install Android command-line tools ────────────────────────────
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && wget -q \
       "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip" \
       -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extracted \
    && mv /tmp/cmdline-tools-extracted/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extracted

# ── Accept all SDK licenses ───────────────────────────────────────────────────
# The 'yes |' pipe accepts every prompt; sdkmanager --licenses writes acceptance
# files to $ANDROID_HOME/licenses so subsequent sdkmanager calls are non-interactive.
RUN yes | sdkmanager --licenses

# ── Install SDK components ────────────────────────────────────────────────────
RUN sdkmanager --install \
    "platform-tools" \
    "platforms;android-${ANDROID_COMPILE_SDK}" \
    "build-tools;${ANDROID_BUILD_TOOLS}"

# Optional: install NDK (comment out if your project doesn't use native code)
# RUN sdkmanager --install "ndk;${ANDROID_NDK_VERSION}"

# Optional: install a system image + emulator for on-device tests in CI
# Uncomment the block below if you need instrumentation tests without a real device.
# RUN sdkmanager --install \
#     "emulator" \
#     "system-images;android-${ANDROID_COMPILE_SDK};google_apis;x86_64" \
#  && echo "no" | avdmanager create avd \
#     --name "ci_avd" \
#     --package "system-images;android-${ANDROID_COMPILE_SDK};google_apis;x86_64" \
#     --device "pixel_6"

# ── Fix ownership so the jenkins user can use the SDK ─────────────────────────
RUN chown -R jenkins:jenkins ${ANDROID_HOME}

# ── Drop back to the jenkins user ────────────────────────────────────────────
USER jenkins

# Expose ANDROID_HOME to Gradle / build scripts running inside Jenkins jobs.
# These are redundant with the ENV lines above but make them explicit in the
# Jenkins process environment, which some plugin wrappers rely on.
ENV ANDROID_HOME=${ANDROID_HOME} \
    ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
