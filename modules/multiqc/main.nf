process MULTIQC {
    conda 'bioconda::multiqc=1.19'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.19--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.19--pyhdfd78af_0' }"

    input:
    path('*')

    output:
    path('*multiqc_report.html'), emit: html
    path("versions.yml"), emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: ''

    """
    cp ${params.logo} .
    cp ${baseDir}/assets/multiqc_config.yaml .
    multiqc -n ${prefix}multiqc_report $args .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
