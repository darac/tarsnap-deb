#!/bin/bash

set -e
PACKAGE=tarsnap
VERSION=1.0.36.1
SIGNING_KEY_YEAR=2015

if [ -n "$1" ]; then
    VERSION="$1"
fi

TAR_URL="https://www.tarsnap.com/download/tarsnap-autoconf-${VERSION}.tgz"
CKSUM_URL="https://www.tarsnap.com/download/tarsnap-sigs-${VERSION}.asc"
KEY_URL="https://www.tarsnap.com/tarsnap-signing-key-${SIGNING_KEY_YEAR}.asc"

PKGDEPS="build-essential debhelper lintian"
MINDEPS="libssl-dev zlib1g-dev e2fslibs-dev"
EXTDEPS="libacl1-dev libattr1-dev libbz2-dev liblzma-dev"
MISSING=""
for I in $PKGDEPS $MINDEPS $EXTDEPS
do
    if ! dpkg -s "$I" >/dev/null 2>&1; then
        MISSING="$I $MISSING"
    fi
done
if [ -n "$MISSING" ]; then
	echo "We need to install the following packages:"
	echo "  $MISSING"
    sudo apt-get update
    sudo apt-get install -y $MISSING
fi

UPSTREAM="tarsnap-autoconf-${VERSION}.tgz"
TARBALL="${PACKAGE}_${VERSION}.orig.tar.gz"
CKSUM="${PACKAGE}_${VERSION}.asc"
SIGNING_KEY="tarsnap-signing-key-${SIGNING_KEY_YEAR}.asc"
wget -c "$TAR_URL" -O "$UPSTREAM"

if hash sha256sum 2>/dev/null; then
	# sha256sum is available, so download an verify the checksum
	wget -c "$CKSUM_URL" -O "$CKSUM"

	if hash gpg 2>/dev/null; then
		# gpg is ALSO available
		wget -c "$KEY_URL" -O "$SIGNING_KEY"

		gpg --import $SIGNING_KEY

		gpg --decrypt $CKSUM | sha256sum -c -

		if [ $? -gt 0 ]; then
			echo "Download verification failed."
			exit 1
		fi
	else
		echo "You can ignore the following error about improperly formatted lines"
		sha256sum -c $CKSUM
		if [ $? -gt 0 ]; then
			echo "Download verification failed."
			exit 1
		fi
	fi
fi

mv "$UPSTREAM" "$TARBALL"

SRC_DIR="${PACKAGE}-${VERSION}"
test -d "$SRC_DIR" && rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"

tar xf "$TARBALL" -C "$SRC_DIR" --strip-components=1

cp -a deb "$SRC_DIR/debian"
sed -i "s/\${VERSION}/${VERSION}/" "$SRC_DIR"/debian/changelog
sed -i "s/\${VERSION}/${VERSION}/" "$SRC_DIR"/debian/*.install

pushd "$SRC_DIR"
dpkg-buildpackage -uc -tc -rfakeroot -k$(gpgconf --list-options gpg | awk -F: '$1 == "default-key" {print $10}'|sed 's/"//g')
popd

rm -rvf ${PACKAGE}-${VERSION}
rm -rvf ${PACKAGE}_*.{dsc,changes,debian.tar.gz}

lintian ${PACKAGE}_${VERSION}-*.deb
