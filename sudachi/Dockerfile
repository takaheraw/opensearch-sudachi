FROM opensearchproject/opensearch:2.17.1

RUN /usr/share/opensearch/bin/opensearch-plugin install --batch \
    https://github.com/WorksApplications/elasticsearch-sudachi/releases/download/v3.3.0/opensearch-2.17.1-analysis-sudachi-3.3.0.zip

COPY system_core.dic config/sudachi/system_core.dic
COPY user_dict.dic config/sudachi/user_dict.dic
