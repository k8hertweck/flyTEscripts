#!/bin/bash
# specify treatment (e.g., ACO) on command line as $1

module load bwa/0.7.7

popte=/work/03177/hertweck/myapps/popoolationte

cd /scratch/03177/hertweck/fly/$1

# set up for loop
for x in 1 2 3 4 5
	do
		# run bwa on each paired end file individually
		bwa bwasw -t 4 ../DmelComb.fas $1"$x"R1.fastq.gz > $1"$x"R1.sam
		bwa bwasw -t 4 ../DmelComb.fas $1"$x"R2.fastq.gz > $1"$x"R2.sam

		# create paired-end information
		perl $popte/samro.pl --sam1 $1"$x"R1.sam --sam2 $1"$x"R2.sam \
			--fq1 $1"$x"R1.fastq --fq2 $1"$x"R2.fastq --output $1"$x"pe-reads.sam

		# sort sam file
		samtools view -Sb $1"$x"pe-reads.sam | samtools sort - $1"$x"pe-reads.sorted
		samtools view $1"$x"pe-reads.sorted.bam > $1"$x"pe-reads.sorted.sam

		# identify forward and reverse insertions
		perl $popte/identify-te-insertsites.pl --input $1"$x"pe-reads.sorted.sam \					
			--te-hierarchy-file ../TEhierarchy5.51.tsv --te-hierarchy-level family \ 
			--narrow-range 75 --min-count 3 --min-map-qual 15 \ 
			--output te-fwd-rev$1"$x".txt

		# obtain TE insertions
		perl $popte/crosslink-te-sites.pl --directional-insertions te-fwd-rev$1"$x".txt \
			--min-dist 74 --max-dist 250 --output te-inserts$1"$x".txt \
			--single-site-shift 100 --poly-n ../poly_n.gtf \
			--te-hierarchy ../TEhierarchy5.51.tsv --te-hier-level order
done