#!/bin/bash
version=""
#支持外部传version
while [ -n "$1" ]
do
    case "$1" in
        --version) version="$2"
            shift ;;
        --) shift
        break ;;
         *) echo "$1 is not an option" ;;
    esac
    shift
done

sed -i '' "s/const version = .*;/const version = '$version';/g" lib/main.dart
dart compile exe bin/flutter_yaml_plus.dart -o pub+

git add .
git commit -m "push $version"