# Clean previous downloads
rm -rf Resources

mkdir -p Resources
cd Resources

# Python
curl -OL https://github.com/bummoblizard/cpython/releases/download/1.0.1/cpython.zip
unzip -q cpython.zip
rm -f cpython.zip

# llvm
for lib in ar link libLLVM lld clang nm dis llc lli opt; do
    curl -OL https://github.com/thebaselab/llvm-project/releases/download/iOS-14/$lib.xcframework.zip
    unzip -q $lib.xcframework.zip -d llvm
    rm -f $lib.xcframework.zip 
done 

# ios_system
for lib in files curl_ios awk text shell tar ios_system; do
    curl -OL https://github.com/holzschu/ios_system/releases/download/v3.0.0/$lib.xcframework.zip
    unzip -q $lib.xcframework.zip -d Term
    rm -f $lib.xcframework.zip 
done

# network_ios
curl -OL https://github.com/holzschu/network_ios/releases/download/v0.2/network_ios.xcframework.zip
unzip -q network_ios.xcframework.zip -d Term
rm -f network_ios.xcframework.zip 

# We are using an older version of SSH / SFTP
curl -OL https://github.com/holzschu/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip
unzip -q ssh_cmd.xcframework.zip -d Term
rm -f ssh_cmd.xcframework.zip

curl -OL https://github.com/holzschu/libssh2-for-iOS/releases/download/v1.2/openssl.xcframework.zip
unzip -q openssl.xcframework.zip -d Term
rm -f openssl.xcframework.zip

curl -OL https://github.com/holzschu/libssh2-for-iOS/releases/download/v1.2/libssh2.xcframework.zip
unzip -q libssh2.xcframework.zip -d Term
rm -f libssh2.xcframework.zip

# lg2
curl -OL https://github.com/holzschu/libgit2/releases/download/ios_1.0/lg2.xcframework.zip
unzip -q lg2.xcframework.zip -d Term
rm -f lg2.xcframework.zip

# Python auxiliaries
for lib in harfbuzz freetype libpng; do
    curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/$lib.xcframework.zip
    unzip -q $lib.xcframework.zip -d PythonAux
    rm -f $lib.xcframework.zip 
done

# Node.js
mkdir -p NodeJS
cd NodeJS
curl -OL https://github.com/1Conan/nodejs-mobile/releases/download/v16.17.0-ios/NodeMobile.xcframework.zip
unzip -q NodeMobile.xcframework.zip
rm -f NodeMobile.xcframework.zip
cd ..

# PHP
curl -OL https://github.com/bummoblizard/php-src/releases/download/v0.2/php.xcframework.zip
unzip -q php.xcframework.zip -d PHP
rm -f php.xcframework.zip

# NMSSH
curl -OL https://github.com/thebaselab/NMSSH/releases/download/2.3.1p/NMSSH.xcframework.zip
unzip -q NMSSH.xcframework.zip
rm -f NMSSH.xcframework.zip

echo "Done!"
