#!/bin/bash -eu

function build_alpine {
    local readonly no_cache_flag=${1}
	local readonly package_name=${2}
	local readonly package_push=${3}
	local readonly package_version=${4}
    local readonly package_is_latest=${5:-}

	local readonly major=$(echo $package_version| cut -d'.' -f 1)
	local readonly minor=$(echo $package_version| cut -d'.' -f 2)
	local readonly patch=$(echo $package_version| cut -d'.' -f 3)
	local readonly minor_version="$major.$minor"

    # Ensure we have the rootfs tarball downloaded to our cache
    local readonly dst_path=${PROCAT_CI_DOWNLOAD_PATH}/alpine/v${package_version}
    local readonly dst_path_main="${dst_path}/main/x86_64"
    local readonly dst_path_community="${dst_path}/community/x86_64"
    local readonly apk_index_filename="APKINDEX.tar.gz"
    local readonly procat_ca_filename="projectcatalysts-ca.pem"
    local readonly procat_ca_prv_filename="projectcatalysts-ca-prv.pem"
    local readonly dst_filename="alpine-minirootfs-${package_version}-x86_64.tar.gz"
    local readonly src_path="http://dl-cdn.alpinelinux.org/alpine/v${minor_version}/releases/x86_64/${dst_filename}"
    local readonly apk_path_main="https://dl-cdn.alpinelinux.org/alpine/v${minor_version}/main/x86_64/${apk_index_filename}"
    local readonly apk_path_community="https://dl-cdn.alpinelinux.org/alpine/v${minor_version}/community/x86_64/${apk_index_filename}"

    # Initialise docker passwords
    procat_ci_docker_init

    # Create the paths if they don't exist already
    mkdir -p ${dst_path_main}
    mkdir -p ${dst_path_community}

    # Download our dependencies
    procat_ci_download ${no_cache_flag} ${src_path} ${dst_path} ${dst_filename}

    # These files are saved to the build server and used during subsequent APK commands within the containers
    procat_ci_download ${no_cache_flag} ${apk_path_main} ${dst_path_main} "${apk_index_filename}"
    procat_ci_download ${no_cache_flag} ${apk_path_community} ${dst_path_community} "${apk_index_filename}"
    procat_ci_download ${no_cache_flag} "http://${PROCAT_CI_BUILD_SERVER}/ca/${procat_ca_filename}" ${PROCAT_CI_DOWNLOAD_PATH} "${procat_ca_filename}"
    procat_ci_download ${no_cache_flag} "http://${PROCAT_CI_BUILD_SERVER}/ca/${procat_ca_prv_filename}" ${PROCAT_CI_DOWNLOAD_PATH} "${procat_ca_prv_filename}"

    # Create the package downloads dirtory it if doesn't exist already
    mkdir -p ${EXEC_CI_SCRIPT_PATH}/downloads/

    # Remove any existing tarballs from the container's download directory
    rm -f ${EXEC_CI_SCRIPT_PATH}/downloads/*

    # Copy the specific version of the rootfs tarball and other dependencies to the container's download directory
    cp ${dst_path}/${dst_filename} -f ${EXEC_CI_SCRIPT_PATH}/downloads/${dst_filename}
    cp ${PROCAT_CI_DOWNLOAD_PATH}/${procat_ca_filename} -f ${EXEC_CI_SCRIPT_PATH}/downloads/${procat_ca_filename}
    cp ${PROCAT_CI_DOWNLOAD_PATH}/${procat_ca_prv_filename} -f ${EXEC_CI_SCRIPT_PATH}/downloads/${procat_ca_prv_filename}

    # Write a project catalysts specific version of the repositories configuration which points to the local build server
    # We must use HTTP here because we need this to work in order to download the certificates package as one of the first
    # steps for the docker build
    echo "http://${PROCAT_CI_BUILD_SERVER}/download/alpine/v${package_version}/main" > ${EXEC_CI_SCRIPT_PATH}/downloads/repositories
    echo "http://${PROCAT_CI_BUILD_SERVER}/download/alpine/v${package_version}/community"  >> ${EXEC_CI_SCRIPT_PATH}/downloads/repositories

    # Build the docker image
	procat_ci_docker_build_image ${no_cache_flag} ${package_name} ${package_push} ${package_version} ${package_is_latest}
}


# configure_ci_environment is used to configure the CI environment variables
function configure_ci_environment {
    #
    # Check the pre-requisite environment variables have been set
    # PROCAT_CI_SCRIPTS_PATH would typically be set in .bashrc or .profile
    # 
    if [ -z ${PROCAT_CI_SCRIPTS_PATH+x} ]; then
        echo "ERROR: A required CI environment variable has not been set : PROCAT_CI_SCRIPTS_PATH"
        echo "       Has '~/.procat_ci_env.sh' been sourced into ~/.bashrc or ~/.profile?"
        env | grep "PROCAT_CI"
        return 1
    fi

    # Configure the build environment if it hasn't been configured already
    source "${PROCAT_CI_SCRIPTS_PATH}/set_ci_env.sh"
}

function build {
    #
    # configure_ci_environment is used to configure the CI environment variables
    # and load the CI common functions
    #
    configure_ci_environment || return $?

    # For testing purposes, default the package name
	if [ -z "${1-}" ]; then
        local package_name="${PROCAT_CI_REGISTRY_SERVER}/procat/docker/alpine-linux"
        pc_log "package_name (default)           : $package_name"
	else
		local package_name=${1}
        pc_log "package_name                     : $package_name"
    fi

    # For testing purposes, default the package version
	if [ -z "${2-}" ]; then
        local package_version="3.19.0"
        pc_log "package_version (default)        : $package_version"
	else
		local package_version=${2}
        pc_log "package_version                  : $package_version"
    fi
    pc_log ""

	# Determine whether the --no-cache command line option has been specified.
	# If it has, attempts to download files from the internet are always made.
	if [ -z "${3-}" ]; then
		local no_cache_flag="false"
	else
		local no_cache_flag=$([ "$3" == "--no-cache" ] && echo "true" || echo "false")
	fi

	build_alpine ${no_cache_flag} ${package_name} push ${package_version} latest
}

# $1 : (Optional) Package Name (registry.projectcatalysts.prv/procat/docker/alpine-linux)
# $2 : (Optional) Package Version (e.g. 3.14.2)
# $3 : (Optional) --no-cache
build ${1:-} ${2:-} ${3:-}
