# ================================
# Build image contains swift compiler and libraries like netcdf or eccodes
# ================================
# FROM ghcr.io/open-meteo/docker-container-build:latest AS build
#
# MRB note to self: I have forked the above in case we need to modify and build our own image in future (no mods as yet)...
#    https://github.com/drmrbrewer/docker-container-build
#    https://hub.docker.com/repository/docker/drmrbrewer/docker-container-build/general
# NOTE... it's a bit of a hassle to update and rebuild this dependency (and not much benefit as I didn't manage to completely 
# avoid any dependency on the open-meteo repo)... so we could just comment out the following again and revert to using the 
# main image above... assuming it's still available...
# this is particularly the case if you're getting swift-related errors because this image contains the swift compiler...
#
FROM drmrbrewer/docker-container-build:latest as build

WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN ENABLE_PARQUET=TRUE swift package resolve

# Copy entire repo into container
COPY . .

# Compile with optimizations
#
# MRB changed -march from 'skylake' to 'native' so that it compiles on arm64... building the arm64 image via depot.dev seems to work even if it doesn't via github itself...
#    RUN swift build -c release -Xcc -march=native
# UPDATE now reverted to what is in main Dockerfile because I think they fixed it for arm64 subsequent to my having to do the above...
#
RUN ENABLE_PARQUET=TRUE MARCH_SKYLAKE=TRUE swift build -c release


# ================================
# Run image contains swift runtime libraries, netcdf, eccodes, cdo and cds utilities
# ================================
# FROM ghcr.io/open-meteo/docker-container-run:latest
#
# MRB note to self: I have forked the above in case we need to modify and build our own image in future (no mods as yet)...
#    https://github.com/drmrbrewer/docker-container-run
#    https://hub.docker.com/repository/docker/drmrbrewer/docker-container-run/general
# NOTE... it's a bit of a hassle to update and rebuild this dependency (and not much benefit as I didn't manage to completely 
# avoid any dependency on the open-meteo repo)... so we could just comment out the following again and revert to using the 
# main image above... assuming it's still available...
#
FROM drmrbrewer/docker-container-run:latest

# Create a openmeteo user and group with /root as its home directory
#
# MRB commented this out... need to do everything as root...
#
# RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /root openmeteo

# Switch to the new home directory
#
# MRB changed this (and all other instances below) from "/app" to "/root"...
#
WORKDIR /root

# Copy build artifacts
#
# MRB removed --chown=openmeteo:openmeteo from each... need to do everything as root...
# MRB also changed from "/app/..." to "/root/..."
#
COPY --from=build /build/.build/release/openmeteo-api /root
RUN mkdir -p /root/Resources
# COPY --from=build /build/Resources /root/Resources
COPY --from=build /build/.build/release/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources /root/Resources/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources
COPY --from=build /build/Public /root/Public

# Attach a volumne
#
# MRB removed chown openmeteo:openmeteo... need to do everything as root...
# MRB also changed "/app/..." to "/root/..."
#
RUN mkdir /root/data
VOLUME /root/data

# MRB added this... needed for data file download logs...
RUN mkdir /root/log

# Ensure all further commands run as the openmeteo user
#
# MRB commented this out... need to do everything as root...
#
# USER openmeteo:openmeteo

# Start the service when the image is run, default to listening on 8080 in production environment 
#
# MRB changed this from 8080 (in master repo) to avoid conflict with port 8080 usage elsewhere (vscode)
# and for consistency with other apps in the suite...
# UPDATE... commented this out now... use this ENTRYPOINT in the Dockerfile which is based off of this one instead...
#
# ENTRYPOINT ["./openmeteo-api"]
# CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
