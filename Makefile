java_version := 11
default_java_version := 11
docker_reg := ghcr.io/
docker_org := hadoop-sandbox
cache := cache
docker := docker

tags_default := latest

dist_target := hadoop-dist
base_image_target := hadoop-base
images_target := hadoop-client \
	hadoop-hdfs-datanode \
	hadoop-hdfs-namenode \
	hadoop-mapred-jobhistoryserver \
	hadoop-yarn-resourcemanager \
	hadoop-yarn-nodemanager

dist_image := $(dist_target)
base_image := $(addsuffix -java-$(java_version), $(base_image_target))
images := $(addsuffix -java-$(java_version), $(images_target))

dist_image_iid := $(addsuffix .iid, $(dist_image))
base_image_iid := $(addsuffix .iid, $(base_image))
images_iid := $(addsuffix .iid, $(images))

images_load := $(addsuffix .load, $(images) $(base_image))

all: $(base_image_iid) $(images_iid)

load: $(images_load)

clean:
	$(RM) *.iid *.load

$(dist_image_iid): Dockerfile
	$(docker) buildx build \
		--iidfile "$@" \
		--output type=image \
		--target "$(patsubst %.iid,%,$@)" \
		-f "$<" .

%.iid: Dockerfile
	$(docker) buildx build \
		--build-arg java_version="$(java_version)" \
		--iidfile "$@" \
		--output type=image \
		--target "$(patsubst %-java-$(java_version).iid,%,$@)" \
		-f "$<" .

$(base_image_iid): $(dist_image_iid)
$(images_iid): $(base_image_iid)

%.load: %.iid
ifeq ($(java_version),$(default_java_version))
	$(docker) buildx build \
		--build-arg java_version="$(java_version)" \
		--target "$(subst -java-$(java_version).load,,$@)" \
		$(foreach tag,$(tags_default), --tag "$(docker_reg)$(docker_org)/$(subst -java-$(java_version).load,,$@):$(tag)") \
		--load . && \
	touch "$@"
else
	$(docker) buildx build \
		--build-arg java_version="$(java_version)" \
		--target "$(subst -java-$(java_version).load,,$@)" \
		$(foreach tag,$(tags_always), --tag "$(docker_reg)$(docker_org)/$(subst -java-$(java_version).load,,$@):$(tag)") \
		--load . && \
	touch "$@"
endif

.PHONY: all push clean
