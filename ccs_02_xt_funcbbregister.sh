#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO SURFACE-BASED FUNCTIONAL IMAGE PREPROCESSING (FREESURFER)
##
## !!!!!*****ALWAYS CHECK YOUR REGISTRATIONS*****!!!!!
##
## Written by R-fMRI master: Xi-Nian Zuo. Dec. 07, 2010, Institute of Psychology, CAS.
##
## Email: zuoxn@psych.ac.cn or zuoxinian@gmail.com.
##########################################################################################################################
## - match the orientation before BBR Ting Xu 2014.06

## subject
subject=$1
## analysisdir
dir=$2
## name of functional directory
func_dir_name=$3
## name of the resting-state scan
rest=$4
## if use the first epi image for registration
if_epi0=$5
## name of target average subject
fsaverage=$6
## func registration directory
func_reg_dir_name=$7
## clean up the old and rerun registration
redo_reg=$8
## directory setup
func_dir=${dir}/${subject}/${func_dir_name}
func_reg_dir=${func_dir}/${func_reg_dir_name}
func_seg_dir=${func_dir}/segment
func_mask_dir=${func_dir}/mask
SUBJECTS_DIR=${dir}

if [ $# -lt 7 ];
then
        echo -e "\033[47;35m Usage: $0 subject analysis_dir func_dir_name rest_name if_epi0 fsaverage func_reg_dir_name remove_old_reg\033[0m"
        exit
fi

if [ ! -d ${SUBJECTS_DIR}/${fsaverage} ]
then
        ln -s ${FREESURFER_HOME}/subjects/${fsaverage} ${SUBJECTS_DIR}/${fsaverage}
fi

cwd=$( pwd )
#if [ -f ${SUBJECTS_DIR}/${subject}/scripts/recon-all.done ]
if [ -f ${SUBJECTS_DIR}/${subject}/mri/wm.mgz ]
then
	## 1. Performing bbregister
	fslmaths ${func_dir}/${rest}_mc.nii.gz -Tmean ${func_dir}/mean_func_mc.nii.gz
	if [ ${redo_reg} = 'true' ]; then
		rm -f ${func_reg_dir};  mkdir -p ${func_reg_dir} ; cd ${func_reg_dir}
		if [ ${if_epi0} = 'true' ]
		then
			fslroi ${func_dir}/${rest}.nii.gz ${func_dir}/epi_t0.nii.gz 0 1
			3dresample -orient RPI -inset ${func_dir}/epi_t0.nii.gz -prefix ${func_dir}/epi_t0_rpi.nii.gz
			fslmaths ${func_dir}/epi_t0_rpi.nii.gz -mas ${func_dir}/${rest}_pp_mask.nii.gz ${func_dir}/epi_t0_brain.nii.gz
			mov0=${func_dir}/epi_t0_brain.nii.gz
		else
			mov0=${func_dir}/example_func_brain.nii.gz
		fi
        ## convert the example_func to RSP orient
        3dresample -orient RSP -prefix ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz -inset ${mov0}
        fslreorient2std ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz > ${func_reg_dir}/rsp2rpi.mat
        convert_xfm -omat ${func_reg_dir}/rpi2rsp.mat -inverse ${func_reg_dir}/rsp2rpi.mat
        ## do fs bbregist
        mov=${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
		bbregister --s ${subject} --mov ${mov} --reg bbregister_rsp2rsp.dof6.init.dat --init-fsl --bold --fslmat flirt_rsp2rsp.init.mtx
		bb_init_mincost=`cut -c 1-8 bbregister_rsp2rsp.dof6.init.dat.mincost`
		comp=`expr ${bb_init_mincost} \> 0.55`
		if [ "$comp" -eq "1" ];
		then
			bbregister --s ${subject} --mov ${mov} --reg bbregister_rsp2rsp.dof6.dat --init-reg bbregister_rsp2rsp.dof6.init.dat --bold --fslmat flirt_rsp2rsp.mtx
			bb_mincost=`cut -c 1-8 bbregister_rsp2rsp.dof6.dat.mincost`
	    	comp=`expr ${bb_mincost} \> 0.55`
			if [ "$comp" -eq "1" ];
            then
				echo "BBregister seems still problematic, needs a posthoc visual inspection!" >> warnings.bbregister
			fi
		else
            cp ${func_reg_dir}/bbregister_rsp2rsp.dof6.init.dat ${func_reg_dir}/bbregister_rsp2rsp.dof6.dat ; 
            cp ${func_reg_dir}/flirt_rsp2rsp.init.mtx ${func_reg_dir}/flirt_rsp2rsp.mtx
            convert_xfm -omat ${func_reg_dir}/flirt.mat -concat ${func_reg_dir}/flirt_rsp2rsp.mtx ${func_reg_dir}/rpi2rsp.mat
            # write the fs registratio matrix from rpi func to rsp anat 
            tkregister2 --mov ${mov0} --targ ${highres} --fsl ${func_reg_dir}/flirt.mat --noedit --reg ${func_reg_dir}/bbregister.dof6.dat			
		fi
	fi	
    
	## 2. write the registration to fsl format
	echo $subject
	cp flirt.mat example_func2highres.mat
	## Create mat file for conversion from subject's anatomical to functional
	convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat

	
else
       	echo "Please run recon-all for this subject first!"
fi

## Back to the directory
cd ${cwd}
