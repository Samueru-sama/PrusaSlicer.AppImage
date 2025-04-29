#!/bin/sh

set -x
PACKAGE=PrusaSlicer
DESKTOP=/usr/resources/applications/PrusaSlicer.desktop
ICON=/usr/resources/icons/PrusaSlicer.png

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
UPINFO="gh-releases-zsync|$(echo $GITHUB_REPOSITORY | tr '/' '|')|continuous|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/tags/v0.6.5/lib4bin"

# Prepare AppDir
mkdir -p ./"$PACKAGE"/AppDir/shared/lib \
  ./"$PACKAGE"/AppDir/usr/share/applications \
  ./"$PACKAGE"/AppDir/etc
cd ./"$PACKAGE"/AppDir

cp -r /usr/resources     ./usr/

cp $DESKTOP              ./usr/share/applications
cp $DESKTOP              ./
cp /"$ICON"              ./

ln -s ./usr/share        ./share
ln -s ./usr/resources    ./resources

# ADD LIBRARIES
rm ./lib4bin || true
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -a -- ./lib4bin -p -v -e -s -k \
  /usr/bin/prusa-slicer \
  /usr/bin/OCCTWrapper.so \
  /usr/lib/"$ARCH"-linux-gnu/gbm/* \
  /usr/lib/"$ARCH"-linux-gnu/libwebkit2gtk* \
  /usr/lib/"$ARCH"-linux-gnu/gdk-pixbuf-*/*/*/* \
  /usr/lib/"$ARCH"-linux-gnu/gio/modules/* \
  /usr/lib/"$ARCH"-linux-gnu/*libnss*.so* \
  /usr/lib/"$ARCH"-linux-gnu/libGL* \
  /usr/lib/"$ARCH"-linux-gnu/libvulkan* \
  /usr/lib/"$ARCH"-linux-gnu/dri/*

rm -f ./lib4bin

# Prusa installs this library in bin normally, so we will place a symlink just in case it is needed
ln -s ../lib/bin/OCCTWrapper.so ./bin/OCCTWrapper.so

# NixOS does not have /usr/lib/locale nor /usr/share/locale, which PrusaSlicer expects
cp -r /usr/lib/locale ./lib/
sed -i -e 's|/usr/lib/locale|././/lib/locale|g' ./bin/prusa-slicer # Since we cannot get LOCPATH to work properly
cp -r /usr/share/locale ./share/
sed -i -e 's|/usr/share/locale|././/share/locale|g' ./shared/lib/libc.so.6 # Since we cannot get LOCPATH to work properly
sed -i -e 's|/usr/lib/locale|././/lib/locale|g' ./shared/lib/libc.so.6  # Since we cannot get LOCPATH to work properly

# Create environment
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}
GSETTINGS_BACKEND=memory
unset LD_LIBRARY_PATH
unset LD_PRELOAD' > ./.env
# LOCPATH=${SHARUN_DIR}/lib/locale:${SHARUN_DIR}/share/locale # This makes PrusaSlicer fail

# Prepare sharun
ln ./sharun ./AppRun
./sharun -g

# MAKE APPIMAGE WITH STATIC RUNTIME
cd ..
rm ./appimagetool || true
wget -q "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool

./appimagetool \
  --comp zstd \
  --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
  -n -u "$UPINFO" "$PWD"/AppDir "$PWD"/"$PACKAGE"-"$VERSION"-"$ARCH".AppImage

mv ./*.AppImage* ../
cd ..
rm -rf ./"$PACKAGE"
echo "All Done!"
