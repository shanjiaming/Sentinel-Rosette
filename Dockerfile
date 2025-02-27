FROM shanjiaming/sentinel-rosette-env:latest

# copy current version of Picus
COPY ./ /Sentinel-Rosette/

WORKDIR /Sentinel-Rosette/
CMD [ "/bin/bash" ]