set -e
working_root=$(pwd)
repo_dir="$working_root/.tmp/netcoredbg" # Concatenate to form the full path

dirname=$(basename "$working_root")

if [ "$dirname" != "netcoredbg-macOS-arm64.nvim" ]; then
  echo "Current directory is not the correct repo folder."
  exit 1
fi

if [ -f "$working_root/.version" ]; then
  installed_version=$(cat "$working_root"/.version)
else
  installed_version="0"
fi

latest_version=$(curl -s https://api.github.com/repos/Samsung/netcoredbg/releases/latest | grep '"tag_name":' | awk -F\" '{print $4}') || {
  echo "Error fetching latest version information"
  exit 1
}

if [ "$latest_version" = "$installed_version" ]; then
  echo "netcoredbg is already up-to-date (version $installed_version)."
  exit 0
fi

# Prompt for user confirmation
echo "A new version of netcoredbg is available."
echo "current: $installed_version, latest: $latest_version"
echo "Do you want to update? (y/n): "

read -r user_input
if [[ ! $user_input =~ ^[Yy]$ ]]; then
  echo "Update cancelled."
  exit 0
fi

if [ ! -d "$repo_dir" ]; then
  mkdir -p "$repo_dir"
  git clone https://github.com/Samsung/netcoredbg.git "$repo_dir" || {
    echo "Error cloning repository"
    exit 1
  }
  cd "$repo_dir"
else
  cd "$repo_dir"
  git fetch || {
    echo "Error fetching repository updates"
    exit 1
  }
fi

# Checkout latest release
git checkout tags/"$latest_version" >/dev/null 2>&1 || {
  echo "Error checking out tag $latest_version"
  exit 1
}

# Clean the build directory if it exists
if [ -d "$repo_dir/build" ]; then
  echo "Cleaning existing build directory..."
  rm -rf "$repo_dir/build"
fi

mkdir build
cd build

CC=clang CXX=clang++ cmake ..

make

src_folder="src"
dest_folder="$working_root/netcoredbg"
files=(
  "libdbgshim.dylib"
  "ManagedPart.dll"
  "Microsoft.CodeAnalysis.CSharp.dll"
  "Microsoft.CodeAnalysis.CSharp.Scripting.dll"
  "Microsoft.CodeAnalysis.dll"
  "Microsoft.CodeAnalysis.Scripting.dll"
  "netcoredbg"
)

# Copy each file, overwriting if it already exists
for file in "${files[@]}"; do
  cp -f "$src_folder/$file" "$dest_folder/"
done

echo "$latest_version" >"$working_root/.version"

cd "$working_root"

echo "Successfully updated netcoredbg"

permission_level=$(gh repo view --json viewerPermission --jq '.viewerPermission')

if [[ $permission_level == "ADMIN" || $permission_level == "WRITE" ]]; then
  # User has admin or write access, ask for confirmation to create a release
  echo "You have permission to create a release."
  echo "Do you want to create a release? (y/n): "
  read -r user_input

  if [[ $user_input =~ ^[Yy]$ ]]; then
    tar -zcvf .tmp/netcoredbg-osx-arm64.tar.gz netcoredbg
    # User confirmed, run the release create command
    gh release create "$latest_version" \
      --title "$latest_version" \
      --notes "Release of version $latest_version" \
      .tmp/netcoredbg-osx-arm64.tar.gz

    rm -rf .tmp/netcoredbg-osx-arm64.tar.gz
  else
    echo "Release creation cancelled."
  fi
fi

cd "$repo_dir"
rm -rf build src/debug/netcoredbg/bin bin

cd "$working_root"
