#!/bin/bash
## running popoolationTE on individual pooled population files
# Usage: specify treatment (e.g., ACO) on command line as $1
# PopoolationTE note: comment out "if of read is supposed to end with /1 or /2 :" warning on line 310 of samro.pl or large output files will result

module load bwa/0.7.7 perl/5.16.2 samtools/1.3

popte=/work/03177/hertweck/myapps/popoolationte

cd /scratch/03177/hertweck/fly/$1

# set up for loop
for x in 1 2 3 4 5
	do
		echo $1"$x"
		# file conversion
		if [ -f $1"$x"R1pop.fastq ]
			then
				echo "fastq files already converted"
			else
				gunzip $1"$x"R1.fastq.gz > $1"$x"R1.fastq
				awk '{if ($2 ~ /^[0-9]/) print $1 "/1"; else print $0}' $1"$x"R1.fastq > $1"$x"R1pop.fastq
				gunzip $1"$x"R2.fastq.gz > $1"$x"R2.fastq
				awk '{if ($2 ~ /^[0-9]/) print $1 "/2"; else print $0}' $1"$x"R2.fastq > $1"$x"R2pop.fastq
		fi

		if [ -f $1"$x"pe-reads.sam ]
			then
				echo "reads already mapped"
			else	
				# run bwa on each paired end file individually
				bwa bwasw ../DmelComb.fas $1"$x"R1pop.fastq > $1"$x"R1.sam
				bwa bwasw ../DmelComb.fas $1"$x"R2pop.fastq > $1"$x"R2.sam

				# create paired-end information
				perl $popte/samro.pl --sam1 $1"$x"R1.sam --sam2 $1"$x"R2.sam \
					--fq1 $1"$x"R1pop.fastq --fq2 $1"$x"R2pop.fastq \
					--output $1"$x"pe-reads.sam

				rm $1"$x"R*pop.fastq
				gzip $1"$x"R*.fastq
		fi
		
		if [ -f $1"$x"pe-reads.sorted.sam ]
			then
				echo "reads already sorted"
			else
				# sort sam file
				samtools view -b $1"$x"pe-reads.sam | \
					samtools sort -O BAM -o $1"$x"pe-reads.sorted.sam
		fi
		
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

		# Use known TE insertions to improve crosslinking 
		perl $popte/update-teinserts-with-knowntes.pl --known ../TEknown5.51.tsv \
			--output te-insertions$1"$x".txt --te-hierarchy-file ../TEhierarchy5.51.tsv \
			--te-hierarchy-level family --max-dist 300 \
			--te-insertions te-inserts$1"$x".txt --single-site-shift 100

		# estimate population frequencies
		perl $popte/estimate-polymorphism.pl --sam-file $1"$x"pe-reads.sorted.sam \
			--te-insert-file te-insertions$1"$x".txt \
			--te-hierarchy-file ../TEhierarchy5.51.tsv --te-hierarchy-level family \
			--min-map-qual 15 --output te-polymorphism$1"$x".txt

		# filter output
		perl $popte/filter-teinserts.pl --te-insertions te-polymorphism$1"$x".txt \
			--output te-poly-filtered$1"$x".txt --discard-overlapping --min-count 10
done
