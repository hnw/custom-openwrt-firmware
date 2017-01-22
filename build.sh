#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $(readlink -e $0))
. ${SCRIPT_DIR}/utils.sh

BRANCH=$1
BOARD=$2
VARIANT=$3

PATCH_FILE="${SCRIPT_DIR}/patch/${BRANCH}-${BOARD}-${VARIANT}.patch"
CACHE_BASE_DIR="${SCRIPT_DIR}/cache"
BUILDROOT_DIRNAME=source
BUILDROOT_DIR="${HOME}/${BUILDROOT_DIRNAME}"

[[ ! -e ${PATCH_FILE} ]] && die "ERROR: cannot access ${PATCH_FILE}"

# Prepare Travis CI's cache directory
declare -A cache_dir=(
    [ccache-host]=${BUILDROOT_DIR}/staging_dir/host/ccache
    [feeds]=${BUILDROOT_DIR}/feeds
)
cd ${BUILDROOT_DIR}/staging_dir/
if path_exists target-*; then
    for dir in target-*; do
        cache_dir["ccache-${dir}"]=${BUILDROOT_DIR}/staging_dir/${dir}/ccache
    done
fi
for key in "${!cache_dir[@]}"; do
    real_dir=${CACHE_BASE_DIR}/${key}
    cache_target=${cache_dir[$key]}
    real_dir_empty=
    if [[ ! -e ${real_dir} ]] ; then
        real_dir_empty=1
        mkdir -p ${real_dir}
    fi
    if [[ ! -d $(dirname ${cache_target}) ]] ; then
        echo "mkdir -p $(dirname ${cache_target})"
        mkdir -p $(dirname ${cache_target})
    fi
    if [[ -e ${cache_target} ]] ; then
        if [[ -d ${cache_target} && -n ${real_dir_empty} ]] ; then
            echo "Copy files in ${cache_target} to ${real_dir}"
            copy_files ${cache_target} ${real_dir}
        fi
        echo "Move ${cache_target} to ${cache_target}.orig"
        mv ${cache_target} ${cache_target}.orig
    fi
    echo "Link ${real_dir} ($(du -sh ${real_dir} | awk '{print $1}')) to ${cache_target}"
    ln -s ${real_dir} ${cache_target}
    if [[ ${key} =~ ^ccache- ]]; then
        CCACHE_DIR=${real_dir} ccache -s | tee /tmp/${key}.log
    fi
done

cd ${BUILDROOT_DIR}

# Update feeds
set_timer
scripts/feeds update -a
success "Updating feeds finished. (elapsed time: $(time_elasped))"

# Bypass Travis CI 10 minutes build timeout
# via: https://github.com/php-build/php-build/issues/134
[[ -n ${TRAVIS} ]] && while true; do echo "..."; sleep 60; done &

# Build image
set_timer
patch -p1 < ${PATCH_FILE}
make
success "Building image finished. (elapsed time: $(time_elasped))"

ls -laR bin/${BOARD}

# Copy images to host
mkdir -p ${SCRIPT_DIR}/bin/
cp bin/${BOARD}/*-{factory,sysupgrade,tftp}.bin ${SCRIPT_DIR}/bin/
cd ${SCRIPT_DIR}/bin/
for file in *.bin ; do
    echo mv ${file} $(echo ${file} | sed -e 's/-\([a-z]*\)-\([a-z]*\)\.bin$/-'${VARIANT}'-\1-\2.bin/' | sed -e 's/^openwrt-/openwrt-'${BRANCH}'-/')
    mv ${file} $(echo ${file} | sed -e 's/-\([a-z]*\)-\([a-z]*\)\.bin$/-'${VARIANT}'-\1-\2.bin/' | sed -e 's/^openwrt-/openwrt-'${BRANCH}'-/')
done

# Show ccache status
for dir in ${CACHE_BASE_DIR}/*; do
    basename=$(basename ${dir})
    if [[ ${basename} =~ ^ccache- ]]; then
        echo ""
        header "ccache status (before build)"
        cat /tmp/${basename}.log
        echo ""
        header "ccache status (after build)"
        CCACHE_DIR=${dir} ccache -s
        rm -f /tmp/${basename}.log
    fi
done
