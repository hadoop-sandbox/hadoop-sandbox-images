java_version := 11
default_java_version := 11
docker_reg :=
docker_org := packet23
platforms := linux/amd64,linux/arm64
cache := cache
docker := docker
hadoop_major := 3
hadoop_minor := 4
hadoop_patch := 0

version_tags := $(hadoop_major) $(hadoop_major).$(hadoop_minor) $(hadoop_major).$(hadoop_minor).$(hadoop_patch)

tags_always := $(foreach version_tag,$(version_tags),$(version_tag)-java-$(java_version)) java-$(java_version)
tags_default := $(tags_always) $(version_tags) latest

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

images_push := $(addsuffix .push, $(images) $(base_image))

all: $(base_image_iid) $(images_iid)

push: $(images_push)

clean:
	$(RM) -r "$(cache)" && \
	$(RM) *.iid *.push

$(dist_image_iid): Dockerfile
	$(docker) buildx build \
		--cache-from "type=local,src=$(cache)" \
		--cache-to "type=local,dest=$(cache)" \
		--iidfile "$@" \
		--platform "$(platforms)" \
		--output type=image \
		--target "$(patsubst %.iid,%,$@)" \
		-f "$<" .

%.iid: Dockerfile
	$(docker) buildx build \
		--cache-from "type=local,src=$(cache)" \
		--cache-to "type=local,dest=$(cache)" \
		--build-arg java_version="$(java_version)" \
		--iidfile "$@" \
		--platform "$(platforms)" \
		--output type=image \
		--target "$(patsubst %-java-$(java_version).iid,%,$@)" \
		-f "$<" .

$(base_image_iid): $(dist_image_iid)
$(images_iid): $(base_image_iid)

%.push: %.iid
ifeq ($(java_version),$(default_java_version))
	$(docker) buildx build \
		--cache-from "type=local,src=$(cache)" \
		--cache-to "type=local,dest=$(cache)" \
		--build-arg java_version="$(java_version)" \
		--platform "$(platforms)" \
		--target "$(subst -java-$(java_version).push,,$@)" \
		$(foreach tag,$(tags_default), --tag "$(docker_reg)$(docker_org)/$(subst -java-$(java_version).push,,$@):$(tag)") \
		--push . && \
	touch "$@"
else
	$(docker) buildx build \
		--cache-from "type=local,src=$(cache)" \
		--cache-to "type=local,dest=$(cache)" \
		--build-arg java_version="$(java_version)" \
		--platform "$(platforms)" \
		--target "$(subst -java-$(java_version).push,,$@)" \
		$(foreach tag,$(tags_always), --tag "$(docker_reg)$(docker_org)/$(subst -java-$(java_version).push,,$@):$(tag)") \
		--push . && \
	touch "$@"
endif

.PHONY: all push clean
