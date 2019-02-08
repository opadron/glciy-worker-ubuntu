FROM scottwittenburg/spack_builder_ubuntu_18.04

RUN RELEASES='https://github.com/Yelp/dumb-init/releases/download' \
 && wget -O /usr/local/bin/dumb-init "$RELEASES/v1.2.2/dumb-init_1.2.2_amd64" \
 && chmod +x /usr/local/bin/dumb-init

COPY entrypoint.py .
COPY glciy-worker.bash .

ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "python", "entrypoint.py"]
CMD ["--help"]
