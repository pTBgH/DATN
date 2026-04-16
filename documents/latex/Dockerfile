FROM texlive/texlive:latest

# Cài đặt Python (cho minted) và Inkscape (cho svg)
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pygments \
    inkscape \
    && rm -rf /var/lib/apt/lists/*