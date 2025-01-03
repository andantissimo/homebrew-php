class Gd < Formula
  desc "Graphics library to dynamically manipulate images"
  homepage "https://libgd.github.io/"
  url "https://github.com/libgd/libgd/releases/download/gd-2.3.3/libgd-2.3.3.tar.xz"
  sha256 "3fe822ece20796060af63b7c60acb151e5844204d289da0ce08f8fdf131e5a61"
  license "GD"
  revision 6

  option "with-avif", "use avif"
  option "with-tiff", "use tiff"
  option "with-webp", "use webp"

  head do
    url "https://github.com/libgd/libgd.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "libavif" if build.with? "avif"
  depends_on "libpng"
  depends_on "libtiff" if build.with? "tiff"
  depends_on "mozjpeg"
  depends_on "webp" if build.with? "webp"

  # revert breaking changes in 2.3.3, remove in next release
  patch do
    url "https://github.com/libgd/libgd/commit/f4bc1f5c26925548662946ed7cfa473c190a104a.patch?full_index=1"
    sha256 "1015f6e125f139a1e922ac4bc2a18abbc498b0142193fa692846bf0f344a3691"
  end

  def install
    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --with-freetype=#{Formula["freetype"].opt_prefix}
      --with-jpeg=#{Formula["mozjpeg"].opt_prefix}
      --with-png=#{Formula["libpng"].opt_prefix}
      --without-x
      --without-xpm
    ]
    args << "--without-avif" unless build.with? "avif"
    args << "--without-tiff" unless build.with? "tiff"
    args << "--without-webp" unless build.with? "webp"

    system "./bootstrap.sh" if build.head?
    system "./configure", *args
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include "gd.h"
      #include <stdio.h>

      int main() {
        gdImagePtr im;
        FILE *pngout;
        int black;
        int white;

        im = gdImageCreate(64, 64);
        black = gdImageColorAllocate(im, 0, 0, 0);
        white = gdImageColorAllocate(im, 255, 255, 255);
        gdImageLine(im, 0, 0, 63, 63, white);
        pngout = fopen("test.png", "wb");
        gdImagePng(im, pngout);
        fclose(pngout);
        gdImageDestroy(im);
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lgd", "-o", "test"
    system "./test"
    assert_path_exists "#{testpath}/test.png"
  end
end
