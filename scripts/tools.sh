#!/bin/bash
# Output build environment information as Markdown
# Used by: vm tools, GitHub Actions

set -euo pipefail

echo "# Build Environment: $(hostname)"
echo ""
echo "## System"
echo ""
echo "| Component | Version |"
echo "|-----------|---------|"
echo "| Distro | $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \") |"
echo "| Kernel | $(uname -r) |"
echo "| glibc | $(ldd --version | head -1 | awk '{print $NF}') |"
echo "| Architecture | $(uname -m) |"
echo ""
echo "## Compilers & Build Tools"
echo ""
echo "| Tool | Version |"
echo "|------|---------|"
if command -v clang &>/dev/null; then
  echo "| clang | $(clang --version | head -1 | sed 's/.*version //' | awk '{print $1}') |"
fi
if command -v clang++ &>/dev/null; then
  echo "| clang++ | $(clang++ --version | head -1 | sed 's/.*version //' | awk '{print $1}') |"
fi
if command -v ld.lld &>/dev/null; then
  echo "| lld | $(ld.lld --version | head -1 | awk '{print $2}') |"
fi
if command -v make &>/dev/null; then
  echo "| make | $(make --version | head -1 | awk '{print $NF}') |"
fi
if command -v cmake &>/dev/null; then
  echo "| cmake | $(cmake --version | head -1 | awk '{print $NF}') |"
fi
if command -v meson &>/dev/null; then
  echo "| meson | $(meson --version) |"
fi
if command -v ninja &>/dev/null; then
  echo "| ninja | $(ninja --version) |"
fi
if command -v autoconf &>/dev/null; then
  echo "| autoconf | $(autoconf --version | head -1 | awk '{print $NF}') |"
fi
if command -v automake &>/dev/null; then
  echo "| automake | $(automake --version | head -1 | awk '{print $NF}') |"
fi
if command -v libtoolize &>/dev/null; then
  echo "| libtool | $(libtoolize --version | head -1 | awk '{print $NF}') |"
fi
if command -v pkg-config &>/dev/null; then
  echo "| pkg-config | $(pkg-config --version) |"
fi
echo ""
echo "## Other Tools"
echo ""
echo "| Tool | Version |"
echo "|------|---------|"
if command -v git &>/dev/null; then
  echo "| git | $(git --version | awk '{print $3}') |"
fi
if command -v curl &>/dev/null; then
  echo "| curl | $(curl --version | head -1 | awk '{print $2}') |"
fi
if command -v wget &>/dev/null; then
  echo "| wget | $(wget --version | head -1 | awk '{print $3}') |"
fi
if command -v bison &>/dev/null; then
  echo "| bison | $(bison --version | head -1 | awk '{print $NF}') |"
fi
if command -v flex &>/dev/null; then
  echo "| flex | $(flex --version | awk '{print $2}') |"
fi
if command -v python3 &>/dev/null; then
  echo "| python3 | $(python3 --version | awk '{print $2}') |"
fi
if command -v gperf &>/dev/null; then
  echo "| gperf | $(gperf --version | head -1 | awk '{print $NF}') |"
fi
