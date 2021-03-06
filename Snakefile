import pandas as pd
from snakemake.utils import validate, min_version

singularity: "/hpcnfs/data/DP/Singularity/rnaseq-snakemake.simg"

##### set minimum snakemake version #####
min_version("5.4.3")


##### load config, cluster config and sample sheets #####

configfile: "config.yaml"
# validate(config, schema="schemas/config.schema.yaml")
CLUSTER = json.load(open(config['cluster_json']))

samples = pd.read_csv(config["samples"], sep = "\t").set_index("sample", drop=False)
# validate(samples, schema="schemas/samples.schema.yaml")

units = pd.read_csv(config["units"], dtype = str, sep = "\t").set_index(["sample", "lane"], drop=False)
units.index = units.index.set_levels([i.astype(str) for i in units.index.levels])  # enforce str in index
# validate(units, schema="schemas/units.schema.yaml")

SAMPLES = set(units["sample"])

rule all: 
	input:
		"04deseq2/pca.pdf",
		"01qc/multiqc/multiqc_report.html",
		expand("05bigwig/{sample}.bw", sample = SAMPLES),
		expand("04deseq2/{contrast}/log2fc{log2fc}_pval{pvalue}/{contrast}_enrichments_log2fc{log2fc}_pval{pvalue}.xlsx", contrast = config["diffexp"]["contrasts"], 
																		pvalue = config["diffexp"]["pvalue"], 
																		log2fc = config["diffexp"]["log2fc"])
		

##### load rules #####

include: "rules/common.smk"
include: "rules/trim.smk"
include: "rules/align.smk"
include: "rules/diffExp.smk"
include: "rules/qc.smk"


##### handle possible errors, clean temp folders #####
onsuccess:
    shell("""
    rm -r fastq/
    qselect -u `whoami` -s E | xargs qdel -Wforce
    """)

onerror:
    print("An error ocurred. Workflow aborted")
    shell("""
	qselect -u `whoami` -s E | xargs qdel -Wforce
    	mail -s "An error occurred. RNA-seq snakemake workflow aborted" `whoami`@ieo.it < {log}
    	""")
