# ================================
# Build image contains swift compiler and libraries like netcdf or eccodes
# ================================
FROM ghcr.io/open-meteo/docker-container-build:latest as build
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Compile with optimizations
RUN MARCH_SKYLAKE=TRUE swift build -c release


# ================================
# Run image contains swift runtime libraries, netcdf, eccodes, cdo and cds utilities
# ================================
FROM ghcr.io/open-meteo/docker-container-run:latest

# Create a openmeteo user and group with /root as its home directory
# MRB commented this out... easier to do everything as root...
# RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /root openmeteo

# Switch to the new home directory
# MRB changed this (and all other instances below) from "/app" to "/root"...
WORKDIR /root

# Copy build artifacts
# MRB removed --chown=openmeteo:openmeteo from each... need to do everything as root...
COPY --from=build /build/.build/release/openmeteo-api /root
RUN mkdir -p /root/Resources
# COPY --from=build /build/Resources /root/Resources
COPY --from=build /build/.build/release/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources /root/Resources/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources
COPY --from=build /build/Public /root/Public

# Attach a volume
# MRB removed chown openmeteo:openmeteo... need to do everything as root...
RUN mkdir /root/data
VOLUME /root/data

# MRB added this... needed for data file download logs...
RUN mkdir /root/log

# Ensure all further commands run as the openmeteo user
# MRB commented this out... need to do everything as root...
# USER openmeteo:openmeteo

# Start the service when the image is run, default to listening on 80 in production environment 
# MRB commented this out... use this ENTRYPOINT in the Dockerfile which is based off of this one instead...
# ENTRYPOINT ["./openmeteo-api"]
# CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "80"]
