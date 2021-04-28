#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO IMAGE REGISTRATION (FLIRT/FNIRT)
##
## !!!!!*****ALWAYS CHECK YOUR REGISTRATIONS*****!!!!!
##
## R-fMRI master: Xi-Nian Zuo. Dec. 07, 2010, Institute of Psychology, CAS.
##
## Email: zuoxn@psych.ac.cn or zuoxinian@gmail.com.
##########################################################################################################################
## -orient the functional to use the FS bbregister, Ting 2014.06
## -add the vcheck at the end, Ting 2014.10

## subject
subject=$1
## analysisdir
dir=$2
## name of anatomical directory
anat_dir_name=$3
## name of functional directory
func_dir_name=$4
## name of the functional data
rest=$5
## standard template which final functional data registered to
standard_template=$6
## name of reg directory for anatomy
anat_reg_dir_name=$7
## name of reg directory for function reg_flirt reg_flirtbbr reg_fsbbr
func_reg_dir_name=$8
## surface template
fsaverage=$9
## ccs_dir
ccs_dir=${10}
## anat_reg_refine
anat_reg_refine=${11}


if [ $# -lt 11 ];
then
    echo -e "\033[47;35m Usage: $0 subject analysis_dir anat_dir_name func_dir_name standard_template anat_reg_dir_name func_reg_dir_name fsaverage ccs_dir anat_reg_refine \033[0m"
    exit
fi

echo ------------------------------------------
echo !!!! RUNNING FUNCTIONAL REGISTRATION !!!!
echo ------------------------------------------

## directory setup
anat_dir=${dir}/${subject}/${anat_dir_name}
func_dir=${dir}/${subject}/${func_dir_name}
func_seg_dir=${func_dir}/segment
anat_reg_dir=${anat_dir}/${anat_reg_dir_name}
func_reg_dir=${func_dir}/${func_reg_dir_name}
func_mask_dir=${func_dir}/mask
SUBJECTS_DIR=${dir}
standard_edge=${ccs_dir}/templates/MNI152_T1_brain_3dedge3_3mm.nii.gz


mkdir -p ${func_reg_dir}

if [ -f ${anat_reg_dir}/highres2standard.mat ]
then
	
	## 1. Copy required images into reg directory
	### copy anatomical
	highres=${anat_dir}/segment/highres.nii.gz
	### copy standard
	standard_head=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz
	standard=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
	### copy example func created earlier
	example_func=${func_dir}/example_func_brain.nii.gz

    cp ${anat_reg_dir}/reorient2rpi.mat ${anat_reg_dir}/rsp2rpi.mgz
    convert_xfm -omat ${anat_reg_dir}/rpi2rsp.nii.gz -inverse ${anat_reg_dir}/rsp2rpi.mgz
	## 2. cd into reg directory
	cd ${func_reg_dir}
    if [ ! -f example_func2highres_rpi.mat ]; then
        convert_xfm -omat example_func2highres_rpi.mat -concat ${anat_reg_dir}/reorient2rpi.mat example_func2highres.mat
        flirt -in ${func_dir}/example_func_brain.nii.gz -ref ${anat_reg_dir}/highres_rpi.nii.gz -applyxfm -init example_func2highres_rpi.mat -out example_func2highres_rpi.nii.gz
    fi 
    if [ ! -f highres_rpi2example_func.mat ]; then
        convert_xfm -omat highres_rpi2example_func.mat -concat highres2example_func.mat ${func_reg_dir}/rpi2rsp.mat
    fi
	## 3. Making mask for surface-based functional data analysis
	#if [ ! -e ${func_mask_dir}/brain.mni305.2mm.nii.gz ]; then
		mkdir -p ${func_mask_dir} ; cd ${func_mask_dir} ; ln -s ${func_dir}/${rest}_pp_mask.nii.gz brain.nii.gz
		#for hemi in lh rh
		#do
			#surf-mask
			#mri_vol2surf --mov brain.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --trgsubject ${subject} --interp nearest --projfrac 0.5 --hemi ${hemi} --o brain.${fsaverage}.${hemi}.nii.gz --noreshape --cortex --surfreg sphere.reg
			#mri_binarize --i brain.${fsaverage}.${hemi}.nii.gz --min .00001 --o brain.${fsaverage}.${hemi}.nii.gz
		#done
		#volume-mask
        #mri_vol2vol --mov brain.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --tal --talres 2 --talxfm talairach.xfm --nearest --no-save-reg --o brain.mni305.2mm.nii.gz
        applywarp --interp=nn --ref=${standard} --in=brain.nii.gz --out=brain.mni152.2mm.nii.gz --warp=${anat_reg_dir}/highres2standard_warp --premat=${func_reg_dir}/example_func2highres.mat
	#fi
	## 3. Coregistering aparc+aseg to native functional spcace
	rm -f ${func_seg_dir}/aparc.a2009s+aseg2func.nii.gz 
	mri_vol2vol --mov ${func_dir}/example_func.nii.gz --targ ${SUBJECTS_DIR}/${subject}/mri/aparc.a2009s+aseg.mgz --inv --interp nearest --o ${func_seg_dir}/aparc.a2009s+aseg2func.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --no-save-reg

	## 4. FUNC->STANDARD
    cd ${func_reg_dir}
  	if [ "${anat_reg_refine}" = "true" ];
  	then
		## Create mat file for registration of functional to standard
		convert_xfm -omat example_func2standard.mat -concat ${anat_reg_dir}/highres2standard_ref.mat example_func2highres.mat
		## apply registration
		flirt -ref ${standard} -in ${example_func} -out example_func2standard -applyxfm -init example_func2standard.mat -interp trilinear
		## Create inverse mat file for registration of standard to functional
		convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat
		## 5. Applying fnirt
		applywarp --ref=${standard_template} --in=${example_func} --out=fnirt_example_func2standard --warp=${anat_reg_dir}/highres2standard_ref_warp --premat=example_func2highres.mat
  	else
		## Create mat file for registration of functional to standard
        convert_xfm -omat example_func2standard.mat -concat ${anat_reg_dir}/highres2standard.mat example_func2highres.mat
        ## apply registration
        flirt -ref ${standard} -in ${example_func} -out example_func2standard -applyxfm -init example_func2standard.mat -interp trilinear
        ## Create inverse mat file for registration of standard to functional
        convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat
        ## 5. Applying fnirt
       	applywarp --ref=${standard_template} --in=${example_func} --out=fnirt_example_func2standard --warp=${anat_reg_dir}/highres2standard_warp --premat=example_func2highres.mat
  	fi
       

    ## 5. Visual check
	if [ ! -e ${anat_reg_dir}/highres_rpi_dedge.nii.gz ]; then
        3dedge3 -input ${anat_reg_dir}/highres_rpi.nii.gz -prefix ${anat_reg_dir}/highres_rpi_3dedge3.nii.gz
    fi
    mkdir -p ${func_regbbr_dir}/vcheck
    cd ${func_reg_dir}
    ## vcheck of the functional registration
    echo "-----visual check of the functional registration-----"
    bg_min=`fslstats example_func2highres_rpi.nii.gz -P 20`
    bg_max=`fslstats example_func2highres_rpi.nii.gz -P 98`
    overlay 1 1 example_func2highres_rpi.nii.gz ${bg_min} ${bg_max} ${anat_reg_dir}/highres_rpi_3dedge3.nii.gz 1 1 vcheck/render_vcheck
    slicer vcheck/render_vcheck -s 2 \
       -x 0.30 sla.png -x 0.40 slb.png -x 0.50 slc.png -x 0.60 sld.png -x 0.70 sle.png \
       -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.70 slk.png \
       -z 0.30 slm.png -z 0.40 sln.png -z 0.50 slo.png -z 0.60 slp.png -z 0.70 slq.png 
    pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
    pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
    pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
    pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png example_func2highres_rpi.png
    mv example_func2highres_rpi.png vcheck/
    title=${subject}.${func_dir_name}.ccs.func.reg_flirtbbr
    convert -font helvetica -fill white -pointsize 36 -draw "text 30,50 '$title'" vcheck/example_func2highres_rpi.png vcheck/example_func2highres_rpi.png
    rm -f sl?.png render_vcheck?.png vcheck/render_vcheck*

    cd ${func_reg_dir}
    ## vcheck of the fnirt registration
    echo "-----visual check of the functional registration-----"
    bg_min=`fslstats fnirt_example_func2standard.nii.gz -P 20`
    bg_max=`fslstats fnirt_example_func2standard.nii.gz -P 98`
    overlay 1 1 fnirt_example_func2standard.nii.gz ${bg_min} ${bg_max} ${standard_edge} 1 1 vcheck/render_vcheck
    slicer vcheck/render_vcheck -s 2 \
           -x 0.30 sla.png -x 0.40 slb.png -x 0.50 slc.png -x 0.60 sld.png -x 0.70 sle.png \
           -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.70 slk.png \
           -z 0.30 slm.png -z 0.40 sln.png -z 0.50 slo.png -z 0.60 slp.png -z 0.70 slq.png 
    pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
    pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
    pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
    pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png fnirt_example_func2standard_edge.png
    mv fnirt_example_func2standard_edge.png vcheck/
    title=${subject}.${func_dir_name}.ccs.func.reg
    convert -font helvetica -fill white -pointsize 36 -draw "text 15,25 '$title'" vcheck/fnirt_example_func2standard_edge.png vcheck/fnirt_example_func2standard_edge.png
    rm -f sl?.png render_vcheck?.png vcheck/render_vcheck*


else
	echo "Please first run registration on anatomical data!"
fi
###***** ALWAYS CHECK YOUR REGISTRATIONS!!! YOU WILL EXPERIENCE PROBLEMS IF YOUR INPUT FILES ARE NOT ORIENTED CORRECTLY (IE. RPI, ACCORDING TO AFNI) *****###

cd ${cwd}
