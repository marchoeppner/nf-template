#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// DEV: Update this block with a description and the name of the pipeline
/**
===============================
Pipeline
===============================

This Pipeline performs ....

### Homepage / git
git@github.com:marchoeppner/pipeline.git

**/

// Pipeline version
params.version = workflow.manifest.version

def summary = [:]

run_name = ( params.run_name == false) ? "${workflow.sessionId}" : "${params.run_name}"

WorkflowMain.initialise(workflow, params, log)

// DEV: Rename this and the file under lib/ to something matching this pipeline (e.g. WorkflowAmplicons)
WorkflowPipeline.initialise( params, log)

// DEV: Rename this to something matching this pipeline, e.g. "AMPLICONS"
include { MAIN } from './workflows/main'

multiqc_report = Channel.from([])

workflow {

    // DEV: Rename to something matching this pipeline (see above)
    MAIN()

    multiqc_report = multiqc_report.mix(MAIN.out.qc).toList()
}

workflow.onComplete {
    log.info "========================================="
    log.info "Duration:		$workflow.duration"
    log.info "========================================="

    def emailFields = [:]
    emailFields['version'] = workflow.manifest.version
    emailFields['session'] = workflow.sessionId
    emailFields['runName'] = run_name
    emailFields['success'] = workflow.success
    emailFields['dateStarted'] = workflow.start
    emailFields['dateComplete'] = workflow.complete
    emailFields['duration'] = workflow.duration
    emailFields['exitStatus'] = workflow.exitStatus
    emailFields['errorMessage'] = (workflow.errorMessage ?: 'None')
    emailFields['errorReport'] = (workflow.errorReport ?: 'None')
    emailFields['commandLine'] = workflow.commandLine
    emailFields['projectDir'] = workflow.projectDir
    emailFields['script_file'] = workflow.scriptFile
    emailFields['launchDir'] = workflow.launchDir
    emailFields['user'] = workflow.userName
    emailFields['Pipeline script hash ID'] = workflow.scriptId
    emailFields['manifest'] = workflow.manifest
    emailFields['summary'] = summary

    email_info = ""
    for (s in emailFields) {
        email_info += "\n${s.key}: ${s.value}"
    }

    def outputDir = new File( "${params.outdir}/pipeline_info/" )
    if( !outputDir.exists() ) {
        outputDir.mkdirs()
    }

    def outputTf = new File( outputDir, "pipeline_report.txt" )
    outputTf.withWriter { w -> w << email_info }	

   // make txt template
    def engine = new groovy.text.GStringTemplateEngine()

    def tf = new File("$baseDir/assets/email_template.txt")
    def txtTemplate = engine.createTemplate(tf).make(emailFields)
    def email_txt = txtTemplate.toString()

    // make email template
    def hf = new File("$baseDir/assets/email_template.html")
    def htmlTemplate = engine.createTemplate(hf).make(emailFields)
    def emailHtml = htmlTemplate.toString()

    def subject = "Pipeline finished ($run_name)."

    if (params.email) {

        def mqcReport = null
        try {
            if (workflow.success && !params.skip_multiqc) {
                mqcReport = multiqc_report.getVal()
                if (mqcReport.getClass() == ArrayList){
                    // DEV: Update name of pipeline
                    log.warn "[Pipeline] Found multiple reports from process 'multiqc', will use only one"
                    mqcReport = mqcReport[0]
                }
            }
        } catch (all) {
            // DEV: Update name of pipeline
            log.warn "[PipelineName] Could not attach MultiQC report to summary email"
        }

        def smailFields = [ email: params.email, subject: subject, email_txt: email_txt, 
            emailHtml: emailHtml, baseDir: "$baseDir", mqcFile: mqcReport, mqcMaxSize: params.maxMultiqcEmailFileSize.toBytes() ]
        def sf = new File("$baseDir/assets/sendmailTemplate.txt")	
        def sendmailTemplate = engine.createTemplate(sf).make(smailFields)
        def sendmailHtml = sendmailTemplate.toString()

    try {
        if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
            // Try to send HTML e-mail using sendmail
            [ 'sendmail', '-t' ].execute() << sendmailHtml
        } catch (all) {
            // Catch failures and try with plaintext
            [ 'mail', '-s', subject, params.email ].execute() << email_txt
        }
    }

}

