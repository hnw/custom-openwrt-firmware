#!/bin/bash
cd openwrt
scripts/feeds update -a
echo 'CONFIG_TARGET_ar71xx_generic_Default=y' >> .config
echo 'CONFIG_TARGET_ar71xx_generic_WZRHPAG300H=y' >> .config
make
ls -laR bin
