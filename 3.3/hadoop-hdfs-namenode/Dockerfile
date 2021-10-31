FROM packet23/hadoop-base:3.3.1
COPY ./docker-entrypoint.d /docker-entrypoint.d
CMD ["gosu", "hdfs", "hdfs", "namenode"]
