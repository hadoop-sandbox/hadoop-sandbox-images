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
	hadoop-yarn-nodemanager \
	hadoop-client-spark \
	hadoop-yarn-nodemanager-spark \
	spark-historyserver

dist_image := $(dist_target)
base_image := $(base_image_target)
images := $(images_target)

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
		--iidfile "$@" \
		--output type=image \
		--target "$(patsubst %.iid,%,$@)" \
		-f "$<" .

$(base_image_iid): $(dist_image_iid)
$(images_iid): $(base_image_iid)

%.load: %.iid
	$(docker) buildx build \
		--target "$(subst .load,,$@)" \
		$(foreach tag,$(tags_default), --tag "$(docker_reg)$(docker_org)/$(subst .load,,$@):$(tag)") \
		--load . && \
	touch "$@"

.PHONY: all load clean
