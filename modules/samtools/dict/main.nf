process SAMTOOLS_DICT {
    conda 'bioconda::samtools=1.19.2'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.19.2--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_0' }"

    publishDir "${params.outdir}/SAMTOOLS", mode: 'copy'

    tag "${fasta}"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path(dict), emit: dict
    path("versions.yml"), emit: versions

    script:
    assembly = meta.assembly
    dict = fasta.getBaseName() + '.dict'

    """
    samtools dict $fasta > $dict

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}

