class PhpFpm < Formula
  desc "General-purpose scripting language"
  homepage "https://www.php.net/"
  # Should only be updated if the new version is announced on the homepage, https://www.php.net/
  url "https://www.php.net/distributions/php-8.1.5.tar.xz"
  mirror "https://fossies.org/linux/www/php-8.1.5.tar.xz"
  sha256 "7647734b4dcecd56b7e4bd0bc55e54322fa3518299abcdc68eb557a7464a2e8a"
  license "PHP-3.01"

  option "with-ffi", "use ffi"
  option "with-gd", "use gd"
  option "with-gmp", "use gmp"
  option "with-intl", "use intl"
  option "with-ldap", "use ldap"
  option "with-mbstring", "use mbstring"
  option "with-odbc", "use odbc"
  option "with-pgsql", "use pgsql"
  option "with-pspell", "use pspell"
  option "with-sodium", "use sodium"
  option "with-tidy", "use tidy"
  option "with-zip", "use zip"

  livecheck do
    url "https://www.php.net/downloads"
    regex(/href=.*?php[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  head do
    url "https://github.com/php/php-src.git"

    depends_on "bison" => :build # bison >= 3.0.0 required to generate parsers
    depends_on "re2c" => :build # required to generate PHP lexers
  end

  depends_on "pkg-config" => :build
  depends_on "argon2"
  depends_on "aspell" if build.with? "pspell"
  depends_on "autoconf"
  depends_on "curl"
  depends_on "andantissimo/php/gd" if build.with? "gd"
  depends_on "gettext"
  depends_on "gmp" if build.with? "gmp"
  depends_on "icu4c" if build.with? "intl"
  depends_on "krb5"
  depends_on "libpq" if build.with? "pgsql"
  depends_on "libsodium" if build.with? "sodium"
  depends_on "libzip" if build.with? "zip"
  depends_on "oniguruma" if build.with? "mbstring"
  depends_on "openldap" if build.with? "ldap"
  depends_on "openssl@1.1"
  depends_on "pcre2"
  depends_on "sqlite"
  depends_on "tidy-html5" if build.with? "tidy"
  depends_on "unixodbc" if build.with? "odbc"

  uses_from_macos "xz" => :build
  uses_from_macos "bzip2"
  uses_from_macos "libedit"
  uses_from_macos "libffi" if build.with? "ffi"
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"
  uses_from_macos "zlib"

  conflicts_with "php"

  on_macos do
    # PHP build system incorrectly links system libraries
    # see https://github.com/php/php-src/pull/3472
    patch :DATA
  end

  def install
    # buildconf required due to system library linking bug patch
    system "./buildconf", "--force"

    inreplace "sapi/fpm/php-fpm.conf.in", ";daemonize = yes", "daemonize = no"
    inreplace "sapi/fpm/www.conf.in" do |s|
      s.gsub! /^user *=/, ";\\0"
      s.gsub! /^group *=/, ";\\0"
      s.gsub! /^listen *=.*/, "listen = /tmp/php-fpm.sock"
      s.gsub! /^;listen.mode *=.*/, "listen.mode = 0666"
    end

    config_path = etc/"php/#{version.major_minor}"
    # Prevent system pear config from inhibiting pear install
    (config_path/"pear.conf").delete if (config_path/"pear.conf").exist?

    # Prevent homebrew from hardcoding path to sed shim in phpize script
    ENV["lt_cv_path_SED"] = "sed"

    # system pkg-config missing
    ENV["KERBEROS_CFLAGS"] = " "
    if OS.mac?
      ENV["LIBS"] = "-lintl"
      ENV["SASL_CFLAGS"] = "-I#{MacOS.sdk_path_if_needed}/usr/include/sasl"
      ENV["SASL_LIBS"] = "-lsasl2"
    else
      ENV["SQLITE_CFLAGS"] = "-I#{Formula["sqlite"].opt_include}"
      ENV["SQLITE_LIBS"] = "-lsqlite3"
      ENV["BZIP_DIR"] = Formula["bzip2"].opt_prefix
    end

    # Each extension that is built on Mojave needs a direct reference to the
    # sdk path or it won't find the headers
    headers_path = "#{MacOS.sdk_path_if_needed}/usr" if OS.mac?

    args = %W[
      --prefix=#{prefix}
      --localstatedir=#{var}
      --sysconfdir=#{config_path}
      --with-config-file-path=#{config_path}
      --with-config-file-scan-dir=#{config_path}/conf.d
      --enable-bcmath=shared
      --enable-calendar=shared
      --enable-ctype=shared
      --enable-dom=shared
      --enable-exif=shared
      --enable-fileinfo=shared
      --enable-ftp=shared
      --enable-fpm
      --enable-json=shared
      --enable-opcache=shared
      --enable-pcntl
      --enable-pdo=shared
      --enable-phar=shared
      --enable-phpdbg
      --enable-phpdbg-readline
      --enable-shmop=shared
      --enable-simplexml=shared
      --enable-soap=shared
      --enable-sockets=shared
      --enable-sysvmsg=shared
      --enable-sysvsem=shared
      --enable-sysvshm=shared
      --enable-tokenizer=shared
      --enable-xml=shared
      --enable-xmlreader=shared
      --enable-xmlwriter=shared
      --with-bz2=shared,#{headers_path}
      --with-curl=shared
      --with-external-pcre
      --with-fpm-user=_www
      --with-fpm-group=_www
      --with-gettext=shared,#{Formula["gettext"].opt_prefix}
      --with-iconv=shared,#{headers_path}
      --with-kerberos
      --with-layout=GNU
      --with-libedit
      --with-libxml
      --with-mhash=#{headers_path}
      --with-mysql-sock=/tmp/mysql.sock
      --with-mysqli=shared,mysqlnd
      --with-openssl
      --with-password-argon2=#{Formula["argon2"].opt_prefix}
      --with-pdo-mysql=shared,mysqlnd
      --with-pdo-sqlite=shared
      --with-pic
      --with-sqlite3=shared
      --with-xmlrpc=shared
      --with-xsl=shared
      --with-zlib
    ]

    args << "--with-ffi=shared" if build.with? "ffi"
    args << "--enable-gd=shared" if build.with? "gd"
    args << "--enable-intl=shared" if build.with? "intl"
    args << "--enable-mbstring=shared" if build.with? "mbstring"
    args << "--with-external-gd" if build.with? "gd"
    args << "--with-gmp=shared,#{Formula["gmp"].opt_prefix}" if build.with? "gmp"
    args << "--with-ldap=shared,#{Formula["openldap"].opt_prefix}" if build.with? "ldap"
    args << "--with-pdo-odbc=shared,unixODBC,#{Formula["unixodbc"].opt_prefix}" if build.with? "odbc"
    args << "--with-pdo-pgsql=shared,#{Formula["libpq"].opt_prefix}" if build.with? "pgsql"
    args << "--with-pgsql=shared,#{Formula["libpq"].opt_prefix}" if build.with? "pgsql"
    args << "--with-pspell=shared,#{Formula["aspell"].opt_prefix}" if build.with? "pspell"
    args << "--with-sodium=shared" if build.with? "sodium"
    args << "--with-tidy=shared,#{Formula["tidy-html5"].opt_prefix}" if build.with? "tidy"
    args << "--with-unixODBC=shared,#{Formula["unixodbc"].opt_prefix}" if build.with? "odbc"
    args << "--with-zip=shared" if build.with? "zip"

    if OS.mac?
      args << "--enable-dtrace"
      args << "--with-ldap-sasl" if build.with? "ldap"
      args << "--with-os-sdkpath=#{MacOS.sdk_path_if_needed}"
    else
      args << "--disable-dtrace"
      args << "--without-ldap-sasl" if build.with? "ldap"
      args << "--without-ndbm"
      args << "--without-gdbm"
    end

    system "./configure", *args
    system "make"
    system "make", "install"

    # Install pear
    system bin/"php",
      "-d", "extension=phar.so",
      "-n", "pear/install-pear-nozlib.phar",
      "-d", share/"php/pear",
      "-b", bin

    # Fix bugs
    inreplace share/"php/pear/PEAR/Command/Remote.php" do |s|
      s.gsub! "$version = is_array($installed['version'])",
        "$version = $installed && is_array($installed['version'])"
      s.gsub! "$installed['version'];", "$installed['version'] ?? null;"
    end

    # Allow pecl to install outside of Cellar
    extension_dir = Utils.safe_popen_read("#{bin}/php-config", "--extension-dir").chomp
    orig_ext_dir = File.basename(extension_dir)
    inreplace bin/"php-config", lib/"php", prefix/"pecl"
    %w[development production].each do |mode|
      inreplace "php.ini-#{mode}", %r{; ?extension_dir = "\./"},
        "extension_dir = \"#{HOMEBREW_PREFIX}/lib/php/pecl/#{orig_ext_dir}\""
    end

    # Use separate ini
    inreplace share/"php/pear/PEAR/Command/Install.php" do |s|
      ini_dir = <<~EOS.gsub(/\n\s*/, ' ').strip
        exec($this->config->get('bin_dir') . DIRECTORY_SEPARATOR .
             $this->config->get('php_prefix') . 'php-config' . $this->config->get('php_suffix') .
             ' --ini-dir')
      EOS
      ini_name = "'ext-' . $pinfo[1]['filename'] . '.ini'"
      ini_data = <<~EOS.gsub(/\n\s*/, ' ').strip
        '[' . $pinfo[1]['filename'] . ']' . PHP_EOL .
        (str_starts_with($param->getPackageType(), 'zendext')
          ? 'zend_extension='
          : 'extension=') . $pinfo[1]['basename'] . PHP_EOL
      EOS
      s.gsub! "$ret = $this->enableExtension(array($pinfo[0]), $param->getPackageType());",
              "$ret = file_put_contents(#{ini_dir} . DIRECTORY_SEPARATOR . #{ini_name}, #{ini_data});"
      s.gsub! "$ret = $this->disableExtension(array($pinfo[0]), $pkg->getPackageType());",
              "$ret = @unlink(#{ini_dir} . DIRECTORY_SEPARATOR . #{ini_name});"
    end

    # Use OpenSSL cert bundle
    openssl = Formula["openssl@1.1"]
    %w[development production].each do |mode|
      inreplace "php.ini-#{mode}", /; ?openssl\.cafile=/,
        "openssl.cafile = \"#{openssl.pkgetc}/cert.pem\""
      inreplace "php.ini-#{mode}", /; ?openssl\.capath=/,
        "openssl.capath = \"#{openssl.pkgetc}/certs\""
    end

    config_files = {
      "php.ini-development"   => "php.ini",
      "php.ini-production"    => "php.ini-production",
      "sapi/fpm/php-fpm.conf" => "php-fpm.conf",
      "sapi/fpm/www.conf"     => "php-fpm.d/www.conf",
    }
    config_files.each_value do |dst|
      dst_default = config_path/"#{dst}.default"
      rm dst_default if dst_default.exist?
    end
    config_path.install config_files

    unless (var/"log/php-fpm.log").exist?
      (var/"log").mkpath
      touch var/"log/php-fpm.log"
    end
  end

  def post_install
    pear_prefix = opt_share/"php/pear"
    pear_files = %W[
      #{pear_prefix}/.depdblock
      #{pear_prefix}/.filemap
      #{pear_prefix}/.depdb
      #{pear_prefix}/.lock
    ]

    %W[
      #{pear_prefix}/.channels
      #{pear_prefix}/.channels/.alias
    ].each do |f|
      chmod 0755, f
      pear_files.concat(Dir["#{f}/*"])
    end

    chmod 0644, pear_files

    # Custom location for extensions installed via pecl
    pecl_path = HOMEBREW_PREFIX/"lib/php/pecl"
    ln_s pecl_path, prefix/"pecl" unless (prefix/"pecl").exist?
    extension_dir = Utils.safe_popen_read("#{bin}/php-config", "--extension-dir").chomp
    php_basename = File.basename(extension_dir)
    php_ext_dir = opt_prefix/"lib/php"/php_basename

    # enable extensions required by pear
    mkdir etc/"php/#{version.major_minor}/conf.d"
    %w[xml].each do |e|
      ext_config_path = etc/"php/#{version.major_minor}/conf.d/ext-#{e}.ini"
      if (php_ext_dir/"#{e}.so").exist?
        ext_config_path.write <<~EOS
          [#{e}]
          extension="#{php_ext_dir}/#{e}.so"
        EOS
      end
    end

    # fix pear config to install outside cellar
    pear_path = HOMEBREW_PREFIX/"share/pear"
    cp_r opt_share/"php/pear/.", pear_path
    {
      "php_ini"  => etc/"php/#{version.major_minor}/php.ini",
      "php_dir"  => pear_path,
      "doc_dir"  => pear_path/"doc",
      "ext_dir"  => pecl_path/php_basename,
      "bin_dir"  => opt_bin,
      "data_dir" => pear_path/"data",
      "cfg_dir"  => pear_path/"cfg",
      "www_dir"  => pear_path/"htdocs",
      "man_dir"  => HOMEBREW_PREFIX/"share/man",
      "test_dir" => pear_path/"test",
      "php_bin"  => opt_bin/"php",
    }.each do |key, value|
      value.mkpath if /(?<!bin|man)_dir$/.match?(key)
      system bin/"pear", "config-set", key, value, "system"
    end

    system bin/"pear", "update-channels"

    mkdir etc/"php/#{version.major_minor}/conf.d"
    %w[
      bcmath bz2
      calendar ctype curl
      dom
      exif
      ffi fileinfo ftp
      gd gettext gmp
      iconv intl
      ldap
      mbstring mysqli
      odbc opcache
      pdo pdo_mysql pdo_odbc pdo_pgsql pdo_sqlite pgsql phar pspell
      shmop simplexml soap sockets sodium sqlite3 sysvmsg sysvsem sysvshm
      tidy tokenizer
      xml xmlreader xmlwriter xsl
      zip
    ].each do |e|
      ext_config_path = etc/"php/#{version.major_minor}/conf.d/ext-#{e}.ini"
      extension_type = (e == "opcache") ? "zend_extension" : "extension"
      if ext_config_path.exist?
        inreplace ext_config_path,
          /#{extension_type}=.*$/, "#{extension_type}=#{php_ext_dir}/#{e}.so"
      elsif (php_ext_dir/"#{e}.so").exist?
        ext_config_path.write <<~EOS
          [#{e}]
          #{extension_type}="#{php_ext_dir}/#{e}.so"
        EOS
      end
    end
  end

  def caveats
    <<~EOS
      To enable PHP via FastCGI add the following to httpd.conf and restart Apache:
          LoadModule proxy_module libexec/apache2/mod_proxy.so
          LoadModule proxy_fcgi_module libexec/apache2/mod_proxy_fcgi.so

          <FilesMatch \\.php$>
              SetHandler "proxy:unix:/tmp/php-fpm.sock|fcgi://localhost"
          </FilesMatch>

      Finally, check DirectoryIndex includes index.php
          DirectoryIndex index.php index.html

      The php.ini and php-fpm.ini file can be found in:
          #{etc}/php/#{version.major_minor}/
    EOS
  end

  plist_options manual: "php-fpm"
  service do
    run [opt_sbin/"php-fpm", "--nodaemonize"]
    run_type :immediate
    keep_alive true
    error_log_path var/"log/php-fpm.log"
    working_dir var
  end
end

__END__
diff --git a/build/php.m4 b/build/php.m4
index 3624a33a8e..d17a635c2c 100644
--- a/build/php.m4
+++ b/build/php.m4
@@ -425,7 +425,7 @@ dnl
 dnl Adds a path to linkpath/runpath (LDFLAGS).
 dnl
 AC_DEFUN([PHP_ADD_LIBPATH],[
-  if test "$1" != "/usr/$PHP_LIBDIR" && test "$1" != "/usr/lib"; then
+  if test "$1" != "$PHP_OS_SDKPATH/usr/$PHP_LIBDIR" && test "$1" != "/usr/lib"; then
     PHP_EXPAND_PATH($1, ai_p)
     ifelse([$2],,[
       _PHP_ADD_LIBPATH_GLOBAL([$ai_p])
@@ -470,7 +470,7 @@ dnl
 dnl Add an include path. If before is 1, add in the beginning of INCLUDES.
 dnl
 AC_DEFUN([PHP_ADD_INCLUDE],[
-  if test "$1" != "/usr/include"; then
+  if test "$1" != "$PHP_OS_SDKPATH/usr/include"; then
     PHP_EXPAND_PATH($1, ai_p)
     PHP_RUN_ONCE(INCLUDEPATH, $ai_p, [
       if test "$2"; then
diff --git a/configure.ac b/configure.ac
index 36c6e5e3e2..71b1a16607 100644
--- a/configure.ac
+++ b/configure.ac
@@ -190,6 +190,14 @@ PHP_ARG_WITH([libdir],
   [lib],
   [no])

+dnl Support systems with system libraries/includes in e.g. /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.14.sdk.
+PHP_ARG_WITH([os-sdkpath],
+  [for system SDK directory],
+  [AS_HELP_STRING([--with-os-sdkpath=NAME],
+    [Ignore system libraries and includes in NAME rather than /])],
+  [],
+  [no])
+
 PHP_ARG_ENABLE([rpath],
   [whether to enable runpaths],
   [AS_HELP_STRING([--disable-rpath],
