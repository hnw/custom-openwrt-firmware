#!/bin/bash
set -e

BRANCH=$1
ARCH=$2
VARIANT=$3
PATCH_FILE="/work/patch/config.${BRANCH}-${ARCH}-${VARIANT}.patch"

[[ ! -e ${PATCH_FILE} ]] && echo "ERROR: cannot access ${PATCH_FILE}" && exit 1

if [[ ${BRANCH} == "15.05.1" && ${ARCH} == "ar71xx" ]] ; then
    TARGET=target-mips_34kc_uClibc-0.9.33.2
    TOOLCHAIN=toolchain-mips_34kc_gcc-4.8-linaro_uClibc-0.9.33.2
fi

# Use TravisCI's ccache directory in build
if [[ -d ${HOME}/.ccache ]] ; then
    for dir in host ${TARGET} ${TOOLCHAIN}; do
        mkdir -p ${HOME}/.ccache/${dir}
        if [[ ! -d ${HOME}/openwrt/staging_dir/${dir} ]] ; then
            mkdir -p ${HOME}/openwrt/staging_dir/${dir}
        fi
        if [[ -e ${HOME}/openwrt/staging_dir/${dir}/ccache ]] ; then
            mv ${HOME}/openwrt/staging_dir/${dir}/ccache ${HOME}/openwrt/staging_dir/${dir}/ccache.orig
        fi
        ln -s ${HOME}/.ccache/${dir} ${HOME}/openwrt/staging_dir/${dir}/ccache
        CCACHE_DIR=${HOME}/.ccache/${dir} ccache -s | tee /tmp/ccache.${dir}.log
    done
fi

# Build image
cd ${HOME}/openwrt
scripts/feeds update -a
patch -p1 < "${PATCH_FILE}"
make

# Copy images to host
mkdir -p /work/bin/
cp bin/${ARCH}/*-{factory,sysupgrade,tftp}.bin /work/bin/
cd /work/bin/
for file in *.bin ; do
    echo mv ${file} $(echo ${file} | sed -e 's/-\([a-z]*\)-\([a-z]*\)\.bin$/-'${VARIANT}'-\1-\2.bin/' | sed -e 's/^openwrt-/openwrt-'${BRANCH}'-/')
    mv ${file} $(echo ${file} | sed -e 's/-\([a-z]*\)-\([a-z]*\)\.bin$/-'${VARIANT}'-\1-\2.bin/' | sed -e 's/^openwrt-/openwrt-'${BRANCH}'-/')
done

# Show ccache status
for dir in host ${TARGET} ${TOOLCHAIN}; do
    if [[ -L ${HOME}/openwrt/staging_dir/${dir}/ccache ]] ; then
        echo "### ccache status (before build, ${dir}) ###"
        cat /tmp/ccache.${dir}.log
        echo ""
        echo "### ccache status (after build, ${dir}) ###"
        CCACHE_DIR=${HOME}/.ccache/${dir} ccache -s
    fi
done

