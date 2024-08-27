#!/bin/bash
if [[ "$1" = "" ]] || [[ "$1" = "help" ]] || [[ "$1" = "--help" ]]  || [[ "$1" = "--?" ]]; then
   echo "Sample:"
   echo "$0"
   echo
   echo "$0 test"
   echo "$0 release"
   echo "$0 release major"
   echo "$0 release minor"
   echo "$0 release revision"
   echo
   exit 0
fi

IS_TEST=0
if [[ "$1" = "test" ]]; then
  IS_TEST=1
fi

xcodebuild -version
if [[ $? -ne 0 ]]; then
    if [[ -e /Applications/Xcode.app/Contents/Developer ]]; then
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
        xcodebuild -version
        if [[ $? -ne 0 ]]; then
            exit -1
        fi
    else
        exit -1
    fi
fi

if [[ "`which xcodebuild`" == "" ]] || [[ "`which xcode-select`" == "" ]]; then
    echo "Xcode is required but has not properly installed."
    echo "https://apps.apple.com/us/app/xcode/id497799835?mt=12"
    exit 1;
fi

if [[ "`which gh`" == "" ]]; then
    echo "GitHub CLI is required but has not properly installed."
    echo "https://cli.github.com"
    exit 1;
else
    gh --version
fi

if [[ "`which pod`" == "" ]]; then
    echo "Cocoapods is required but has not properly installed."
    echo "https://cocoapods.org"
    exit 1;
else
    echo "Cocoapods `pod --version`"
fi

pod trunk me
if [[ $? -ne 0 ]]; then
  echo "Please register like below before retry: "
  echo
  echo "pod trunk register `defaults read MobileMeAccounts Accounts | grep AccountDescription | awk -F'\"' '{print $2}'` '`whoami`' --description='`hostname -s`'"
  echo
  exit -1
fi

GIT_USER="`grep 'user:' ~/.config/gh/hosts.yml | awk -F': ' '{print $NF}'`"
GIT_BASE_BRANCH="main"
GIT_REPOSITORY="${PWD##*/}"

echo "git username:    $GIT_USER"
echo "git repository:  $GIT_REPOSITORY"
echo "git base branch: $GIT_BASE_BRANCH"
echo

gh repo view $GIT_REPOSITORY
if [[ $? -ne 0 ]]; then
    gh repo create $GIT_REPOSITORY --public
    if [[ $? -ne 0 ]]; then
        echo "Unable to create repository in GitHub"
        exit 1
    fi
fi

if [[ ! -e README.md ]]; then
    echo "# ${GIT_REPOSITORY}" >> README.md
fi

if [[ ! -e LICENSE ]]; then
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/LICENSE > LICENSE
    sed -i '' -e "s/kelvinjjwong/${GIT_USER}/" LICENSE
    CURYEAR=`date '+%Y'`
    sed -i '' -e "s/2024/${CURYEAR}/" LICENSE
fi

if [[ ! -e .gitignore ]]; then
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/template/.gitignore > .gitignore
fi

if [[ ! -e ${GIT_REPOSITORY}.podspec ]]; then
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/template/podspec > ${GIT_REPOSITORY}.podspec
    sed -i '' -e "s/PROJECT_NAME/${GIT_REPOSITORY}/" ${GIT_REPOSITORY}.podspec
    sed -i '' -e "s/PROJECT_VERSION/1.0.0/" ${GIT_REPOSITORY}.podspec
    sed -i '' -e "s/GIT_USER/${GIT_USER}/" ${GIT_REPOSITORY}.podspec
    sed -i '' -e "s/GIT_EMAIL/`git config user.email`/" ${GIT_REPOSITORY}.podspec
    MACOS_VERSION=`sw_vers | grep ProductVersion | awk -F' ' '{print $NF}' | awk -F'.' '{print $1".0"}'`
    sed -i '' -e "s/MACOS_VERSION/${MACOS_VERSION}/" ${GIT_REPOSITORY}.podspec
    sed -i '' -e "s/SWIFT_VERSION/5.0/" ${GIT_REPOSITORY}.podspec
fi

if [[ ! -e Package.swift ]]; then
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/template/Package.swift > Package.swift
    sed -i '' -e "s/PROJECT_NAME/${GIT_REPOSITORY}/" Package.swift
fi

git status
if [[ $? -ne 0 ]]; then
    git init
    git add -A
    git branch -M ${GIT_BASE_BRANCH}
    git remote add origin git@github.com:${GIT_USER}/${GIT_REPOSITORY}.git
    git commit -m "initial commit"
    git push -u origin ${GIT_BASE_BRANCH}
    if [[ $? -ne 0 ]]; then
        exit $?
    fi
fi

versionPos="revision"
versionChange=0
if [[ "$1" = "release" ]]; then
   versionChange=1
   if [[ "$2" = "major" ]]; then
       versionPos="major"
   elif [[ "$2" = "minor" ]]; then
       versionPos="minor"
   else
       versionPos="revision"
   fi
fi

#if [[ "$1 $2" = "version down" ]]; then
#   versionChange=-1
#   if [[ "$3" = "major" ]]; then
#       versionPos="major"
#   elif [[ "$3" = "minor" ]]; then
#       versionPos="minor"
#   else
#       versionPos="revision"
#   fi
#fi


# JUMP VERSION

PODSPEC="${GIT_REPOSITORY}.podspec"
PREV_VERSION=`grep s.version $PODSPEC | head -1 | awk -F' ' '{print $NF}' | sed 's/"//g'`

if [[ $versionChange -ne 0 ]]; then
    if [[ $versionChange -eq 1 ]]; then
        if [[ "$versionPos" = "major" ]]; then
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1+1".0.0"}'`
        elif [[ "$versionPos" = "minor" ]]; then
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1"."$2+1".0"}'`
        else
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1"."$2"."$3+1}'`
        fi
        
    else
        if [[ "$versionPos" = "major" ]]; then
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1-1"."$2"."$3}'`
        elif [[ "$versionPos" = "minor" ]]; then
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1"."$2-1"."$3}'`
        else
            NEW_VERSION=`echo $PREV_VERSION | awk -F'.' '{print $1"."$2"."$3-1}'`
        fi
    fi
    echo "Current version: $PREV_VERSION"
    echo "   Next version: $NEW_VERSION"
    sed -i '' -e 's/s.version     = ".*"/s.version     = "'$NEW_VERSION'"/' $PODSPEC
    sed -i '' -e 's/"'$PREV_VERSION'"/"'$NEW_VERSION'"/g' -e 's/~> '$PREV_VERSION'/~> '$NEW_VERSION'/g' README.md
fi

# PUSH CHANGES BEFORE POD TESTING

GIT_BRANCH=`git status | grep "On branch" | head -1 | awk -F' ' '{print $NF}'`
CURRENT_VERSION=`grep s.version $PODSPEC | head -1 | awk -F' ' '{print $NF}' | sed 's/"//g'`

GIT_REMOTE_REPO=`git config --get remote.origin.url`
if [ "$GIT_REMOTE_REPO" = "" ]; then
    git remote add origin git@github.com:${GIT_USER}/${GIT_REPOSITORY}.git
    git branch -M ${GIT_BASE_BRANCH}
    git push -u origin ${GIT_BASE_BRANCH}
fi

if [[ ! -e Sources/${GIT_REPOSITORY}/ ]]; then
    mkdir -p Sources/${GIT_REPOSITORY}/
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/template/PROJECT_NAME.swift > Sources/${GIT_REPOSITORY}/${GIT_REPOSITORY}.swift
    sed -i '' -e "s/PROJECT_NAME/${GIT_REPOSITORY}/" Sources/${GIT_REPOSITORY}/${GIT_REPOSITORY}.swift
    git add Sources/${GIT_REPOSITORY}/${GIT_REPOSITORY}.swift
    git commit -m "initial commit"
    git push
fi

if [[ ! -e Tests/${GIT_REPOSITORY}Tests/ ]]; then
    mkdir -p Tests/${GIT_REPOSITORY}Tests/
    curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/template/PROJECT_NAMETests.swift > Tests/${GIT_REPOSITORY}Tests/${GIT_REPOSITORY}Tests.swift
    sed -i '' -e "s/PROJECT_NAME/${GIT_REPOSITORY}/" Tests/${GIT_REPOSITORY}Tests/${GIT_REPOSITORY}Tests.swift
    git add Tests/${GIT_REPOSITORY}Tests/${GIT_REPOSITORY}Tests.swift
    git commit -m "initial commit"
    git push
fi

EXIST_TAG=`git ls-remote --tags origin | tr '/' ' ' | awk -F' ' '{print $NF}' | grep $CURRENT_VERSION`
if [[ "$EXIST_TAG" != "" ]]; then
    echo "$CURRENT_VERSION already exist in git repository. Aborted following build steps to avoid duplication."
    echo
    exit -1
fi

if [[ "$GIT_BRANCH" != "$CURRENT_VERSION" ]]; then
    git branch $CURRENT_VERSION
    git checkout $CURRENT_VERSION
fi
git commit -am "build version $CURRENT_VERSION"
if [[ $? -eq 0 ]]; then
    git push --set-upstream origin $CURRENT_VERSION
    if [[ $? -ne 0 ]]; then
       exit -1
    fi
else
    echo 
    echo "You need to 'git add' and 'git commit' ALL untracked files before perform testing."
    echo
    exit 1
fi

# POD TESTING

pod spec lint $PODSPEC --allow-warnings
if [[ $? -ne 0 ]]; then
    exit -1
fi

if [[ $IS_TEST -ne 0 ]]; then
    echo
    echo "Test only, abort release procedure."
    exit 0
fi

# RELEASE

GH=`which gh`
if [[ "$GH" != "" ]]; then
    gh pr status
    gh pr create --title "$CURRENT_VERSION" --body "**Full Changelog**: https://github.com/${GIT_USER}/${GIT_REPOSITORY}/compare/$PREV_VERSION...$CURRENT_VERSION"
    gh pr list
    GH_PR=`gh pr list | tail -1 | tr '#' ' ' | awk -F' ' '{print $1}'`
    gh pr merge $GH_PR -m
    if [[ $? -ne 0 ]]; then
        exit -1
    fi
    gh pr status
    git pull
    git checkout ${GIT_BASE_BRANCH}
    git pull
    gh release create $CURRENT_VERSION --generate-notes
    if [[ $? -ne 0 ]]; then
        exit -1
    fi
    
    pod trunk push $PODSPEC --allow-warnings
else
    SOURCE_URL=`grep s.source $PODSPEC | head -1 | awk -F'"' '{print $2}' | sed 's/.\{4\}$//'`
    echo "If success, you can then:"
    echo
    echo "1 # publish new release by tagging new version [$CURRENT_VERSION] in git repository"
    echo "$SOURCE_URL/releases"
    echo "with auto markdown release note"
    echo "**Full Changelog**: $SOURCE_URL/compare/$PREV_VERSION...$CURRENT_VERSION"
    echo ""
    echo "2 # push new version to Cocoapods trunk"
    echo "pod trunk push $PODSPEC"
    echo
    echo "OR install GitHub CLI to automate these steps:"
    echo
    echo "brew install gh"
    echo "gh auth login"
    echo
    echo "https://cli.github.com"
    echo
fi
