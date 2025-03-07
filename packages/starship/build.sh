TERMUX_PKG_HOMEPAGE=https://starship.rs
TERMUX_PKG_DESCRIPTION="A minimal, blazing fast, and extremely customizable prompt for any shell"
TERMUX_PKG_LICENSE="ISC"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=1.6.2
TERMUX_PKG_SRCURL=https://github.com/starship/starship/archive/v$TERMUX_PKG_VERSION.tar.gz
TERMUX_PKG_SHA256=4151b3133f3fb0e649847f7714ac77282a4e2dd47fda7f5a08a4f7e87f44b277
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_DEPENDS="openssl, zlib"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="--all-features"

termux_step_pre_configure() {
	termux_setup_rust
	: "${CARGO_HOME:=$HOME/.cargo}"
	export CARGO_HOME

	cargo fetch --target $CARGO_TARGET_NAME

	local d
	for d in $CARGO_HOME/registry/src/github.com-*/libgit2-sys-*/libgit2; do
		patch --silent -p1 -d ${d} \
			<$TERMUX_SCRIPTDIR/packages/libgit2/src-rand.c.patch || :
		cp $TERMUX_SCRIPTDIR/packages/libgit2/getloadavg.c ${d}/src/ || :
	done

	CFLAGS+=" $CPPFLAGS"
	if [ $TERMUX_ARCH = arm ]; then
		CFLAGS+=" -fno-integrated-as"
	fi

	mv $TERMUX_PREFIX/lib/libz.so.1{,.tmp}
	mv $TERMUX_PREFIX/lib/libz.so{,.tmp}

	local _CARGO_TARGET_LIBDIR=target/$CARGO_TARGET_NAME/release/deps
	mkdir -p $_CARGO_TARGET_LIBDIR
	ln -sfT $(readlink -f $TERMUX_PREFIX/lib/libz.so.1.tmp) \
		$_CARGO_TARGET_LIBDIR/libz.so.1
	ln -sfT $(readlink -f $TERMUX_PREFIX/lib/libz.so.tmp) \
		$_CARGO_TARGET_LIBDIR/libz.so
}

termux_step_post_make_install() {
	mv $TERMUX_PREFIX/lib/libz.so.1{.tmp,}
	mv $TERMUX_PREFIX/lib/libz.so{.tmp,}
}

termux_step_post_massage() {
	rm -f lib/libz.so.1
	rm -f lib/libz.so
}

termux_step_create_debscripts() {
	cat <<-EOF >./postinst
		#!$TERMUX_PREFIX/bin/sh
		mkdir -p $TERMUX_PREFIX/share/bash-completions/completions
		mkdir -p $TERMUX_PREFIX/share/fish/vendor_completions.d
		mkdir -p $TERMUX_PREFIX/share/zsh/site-functions

		starship completions bash > $TERMUX_PREFIX/share/bash-completions/completions/starship
		starship completions fish > $TERMUX_PREFIX/share/fish/vendor_completions.d/starship.fish
		starship completions zsh > $TERMUX_PREFIX/share/zsh/site-functions/_starship
	EOF

	cat <<-EOF >./prerm
		#!$TERMUX_PREFIX/bin/sh
		rm -f $TERMUX_PREFIX/share/bash-completions/completions/starship
		rm -f $TERMUX_PREFIX/share/fish/vendor_completions.d/starship.fish
		rm -f $TERMUX_PREFIX/share/zsh/site-functions/_starship
	EOF
}
