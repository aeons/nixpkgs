{ stdenv, fetchFromGitHub, fetchpatch, pkgconfig, python2Packages, makeWrapper
, bash, libsamplerate, libsndfile, readline

# Optional Dependencies
, dbus ? null, libffado ? null, alsaLib ? null
, libopus ? null

# Extra options
, prefix ? ""
}:

with stdenv.lib;
let
  inherit (python2Packages) python dbus-python;
  shouldUsePkg = pkg: if pkg != null && stdenv.lib.any (x: x == stdenv.system) pkg.meta.platforms then pkg else null;

  libOnly = prefix == "lib";

  optDbus = shouldUsePkg dbus;
  optPythonDBus = if libOnly then null else shouldUsePkg dbus-python;
  optLibffado = if libOnly then null else shouldUsePkg libffado;
  optAlsaLib = if libOnly then null else shouldUsePkg alsaLib;
  optLibopus = shouldUsePkg libopus;
in
stdenv.mkDerivation rec {
  name = "${prefix}jack2-${version}";
  version = "1.9.10";

  src = fetchFromGitHub {
    owner = "jackaudio";
    repo = "jack2";
    rev = "v${version}";
    sha256 = "1a2213l7x6sgqg2hq3yhnpvvvqyskhsmx8j3z0jgjsqwz9xa3wbr";
  };

  nativeBuildInputs = [ pkgconfig python makeWrapper ];
  buildInputs = [ python libsamplerate libsndfile readline
    optDbus optPythonDBus optLibffado optAlsaLib optLibopus
  ];

  prePatch = ''
    substituteInPlace svnversion_regenerate.sh --replace /bin/bash ${bash}/bin/bash
  '';

  patches = [
    ./jack-gcc5.patch
    (fetchpatch {
      url = "https://github.com/jackaudio/jack2/commit/ff1ed2c4524095055140370c1008a2d9cccc5645.patch";
      sha256 = "0vywakbmlskvs9ginij9ilk39wjyzg7w6cf1qxp11hb0hj69fir5";
    })
  ];

  configurePhase = ''
    python waf configure --prefix=$out \
      ${optionalString (optDbus != null) "--dbus"} \
      --classic \
      ${optionalString (optLibffado != null) "--firewire"} \
      ${optionalString (optAlsaLib != null) "--alsa"} \
      --autostart=${if (optDbus != null) then "dbus" else "classic"} \
  '';

  buildPhase = ''
    python waf build
  '';

  installPhase = ''
    python waf install
  '' + (if libOnly then ''
    rm -rf $out/{bin,share}
    rm -rf $out/lib/{jack,libjacknet*,libjackserver*}
  '' else ''
    wrapProgram $out/bin/jack_control --set PYTHONPATH $PYTHONPATH
  '');

  meta = {
    description = "JACK audio connection kit, version 2 with jackdbus";
    homepage = "http://jackaudio.org";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
    maintainers = with maintainers; [ goibhniu wkennington ];
  };
}
