##------- FASTQC -------##
rule fastqc:
	input:  
		get_trimmed_forward
	output: 
		"01qc/fqc/{sample}_fastqc.zip"
	log:	
		"00log/fqc/{sample}.log"
	params:
		folder_name = "01qc/fqc/",
		tmp = "01qc/fqc/{sample}.fastq"
	threads: 
		CLUSTER["fastqc"]["cpu"]
	message: 
		"Running fastqc for {input}"
	benchmark:
		".benchmarks/{sample}.fastqc.benchmark.txt"
	shadow: 
		"minimal"
	shell:
		"""
		ln -s "$(pwd)/{input}" {params.tmp}
		fastqc -o {params.folder_name} -f fastq -t {threads} --noextract {params.tmp} 2> {log}
		"""


##------- RSEQC -------##

rule rseqc_gtf2bed:
	input:
		config["ref"]["annotation"]
	output:
		bed = "01qc/rseqc/annotation.bed",
		db = temp("01qc/rseqc/annotation.db")
	log:
		"00log/rseqc_gtf2bed.log"
	script:
		"../scripts/gtf2bed.py"


rule rseqc_stat:
	input:
		rules.star.output.bam,
	output:
		"01qc/rseqc/{sample}.stats.txt"
	priority: 1
	log:
		"00log/rseqc/rseqc_stat/{sample}.log"
	shell:
		"bam_stat.py -i {input} > {output} 2> {log}"

		
rule rseqc_innerdis:
	input:
		bam = rules.star.output.bam,
		bed = "01qc/rseqc/annotation.bed"
	output:
		"01qc/rseqc/{sample}.inner_distance_freq.inner_distance_freq.txt"
	priority: 1
	log:
		"00log/rseqc/rseqc_innerdis/{sample}.log"
	params:
		prefix="01qc/rseqc/{sample}.inner_distance_freq"
	shell:
		"inner_distance.py -r {input.bed} -i {input.bam} -o {params.prefix} > {log} 2>&1"


rule rseqc_readdis:
	input:
		bam = rules.star.output.bam,
		bed = "01qc/rseqc/annotation.bed"
	output:
		"01qc/rseqc/{sample}.read_distribution.txt"
	priority: 1
	log:
		"00log/rseqc/rseqc_readdis/{sample}.log"
	shell:
		"read_distribution.py -r {input.bed} -i {input.bam} > {output} 2> {log}"

rule rseqc_geneCoverage:
	input:
		bam   = rules.star.output.bam,
		index = rules.star.output.index,
		bed   = "01qc/rseqc/annotation.bed"
	output:
		"01qc/rseqc/{sample}.geneBodyCoverage.geneBodyCoverage.txt"
	params:
		prefix="01qc/rseqc/{sample}.geneBodyCoverage"
	priority: 1
	shadow:
		"minimal"
	log:
		"00log/rseqc/rseqc_geneCoverage/{sample}.log"
	shell:
		"geneBody_coverage.py -r {input.bed} -i {input.bam}  -o {params.prefix} 2> {log}"

# rule rseqc_readdup:
#	input:
#		rules.star.output.bam
#	output:
#		"01qc/rseqc/{sample}.readdup.DupRate_plot.pdf"
#	priority: 1
#	log:
#		"00log/rseqc/rseqc_readdup/{sample}.log"
#	params:
#		prefix="01qc/rseqc/{sample}.readdup"
#	shell:
#		"read_duplication.py -i {input} -o {params.prefix} > {log} 2>&1"


# rule rseqc_readgc:
#	input:
#		ules.star.output.bam
#	output:
#		01qc/rseqc/{sample}.readgc.GC_plot.pdf"
#	priority: 1
#	log:
#		00log/rseqc/rseqc_readgc/{sample}.log"
#	params:
#		refix="01qc/rseqc/{sample}.readgc"
#	shell:
#		read_GC.py -i {input} -o {params.prefix} > {log} 2>&1"

# rule rseqc_infer:
#	input:
#		bam=rules.star.output.bam,
#		bed="01qc/rseqc/annotation.bed"
#	output:
#		"01qc/rseqc/{sample}.infer_experiment.txt"
#	priority: 1
#	log:
#		"00log/rseqc/rseqc_infer/{sample}.log"
#	shell:
#		"infer_experiment.py -r {input.bed} -i {input.bam} > {output} 2> {log}"

# rule rseqc_junction_annotation:
#	input:
#		bam = rules.star.output.bam,
#		bed = "01qc/rseqc/annotation.bed"
#	output:
#		"01qc/rseqc/{sample}.junctionanno.junction.bed"
#	priority: 1
#	log:
#		"00log/rseqc/rseqc_junction_annotation/{sample}.log"
#	params:
#		extra=r"-q 255",  # STAR uses 255 as a score for unique mappers
#		prefix="01qc/rseqc/{sample}.junctionanno"
#	shell:
#		"junction_annotation.py {params.extra} -i {input.bam} -r {input.bed} -o {params.prefix} "
#		"> {log[0]} 2>&1"


# rule rseqc_junction_saturation:
#	input:
#		bam=rules.star.output.bam,
#		bed="01qc/rseqc/annotation.bed"
#	output:
#		"01qc/rseqc/{sample}.junctionsat.junctionSaturation_plot.pdf"
#	priority: 1
#	log:
#		"00log/rseqc/rseqc_junction_saturation/{sample}.log"
#	params:
#		extra=r"-q 255", 
#		prefix="01qc/rseqc/{sample}.junctionsat"
#	shell:
#		"junction_saturation.py {params.extra} -i {input.bam} -r {input.bed} -o {params.prefix} "
#		"> {log} 2>&1"


# ---------------- MultiQC report ----------------- #
rule multiQC_inputs:
	input:
		expand("01qc/fqc/{sample}_fastqc.zip", sample = SAMPLES),
		expand("02alignments/{sample}/Log.final.out", sample = SAMPLES),
		expand("03featureCounts/{sample}/{sample}.featureCounts.summary", sample = SAMPLES),
		expand("01qc/rseqc/{sample}.stats.txt", sample = SAMPLES),
		expand("01qc/rseqc/{sample}.inner_distance_freq.inner_distance_freq.txt", sample = SAMPLES),
		expand("01qc/rseqc/{sample}.read_distribution.txt", sample = SAMPLES),
		expand("00log/alignments/rm_dup/{sample}.log", sample = SAMPLES),
		expand("01qc/rseqc/{sample}.geneBodyCoverage.geneBodyCoverage.txt", sample = SAMPLES),
	output: 
		file = "01qc/multiqc/multiqc_inputs.txt"
	message:
		"create file containing all multiqc input files"
	run:
		with open(output.file, 'w') as outfile:
			for fname in input:
					outfile.write(fname + "\n")

rule multiQC:
	input:
		"01qc/multiqc/multiqc_inputs.txt"
	output: 
		"01qc/multiqc/multiqc_report.html"
	params:
		log_name = "multiqc_report",
		folder   = "01qc/multiqc"
	log:
		"00log/multiqc/multiqc.log"
	message:
		"multiqc for all logs"
	shell:
		"""
		multiqc -o {params.folder} -l {input} -f -v -n {params.log_name} 2> {log}
		"""
