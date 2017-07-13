editLinesPlan(){
    PLANFILE=$1
    printf "Altering plan for compliance with XIO export: $PLANFILE \n" | tee -a $LOGFILE
    sed -i '4d' $PLANFILE
    sed -i '7 a 0' $PLANFILE
}

getCtStudyUid(){
    STUDYINFO=$1
	STUDINFVER=$(head -n 1 $STUDYINFO)
	if [ "$STUDINFVER" == "00111016" ]; then
	  CT_IDS_OFFSET=12
	else
	  CT_IDS_OFFSET=13
	fi
    CT_IDS_ORIG=$(head -n $CT_IDS_OFFSET $STUDYINFO | tail   -n 2)
    echo $(echo $CT_IDS_ORIG | cut -d' ' -f1)
}

getCtSeriesUid(){
    STUDYINFO=$1
	STUDINFVER=$(head -n 1 $STUDYINFO)
	if [ "$STUDINFVER" == "00111016" ]; then
	  CT_IDS_OFFSET=12
	else
	  CT_IDS_OFFSET=13
	fi
    CT_IDS_ORIG=$(head -n $CT_IDS_OFFSET $STUDYINFO | tail   -n 2)
    echo $(echo $CT_IDS_ORIG | cut -d' ' -f2)
}

FOCUS=$1
STOREDIR=$2
TEMPDIR=$3
PATIENTLOCATION=$4
PLANLOCATION=$5
PATID=$6
PLANID=$7
PLANTYPE=$8
LOGFILE=$9
OUTPUTDIR=$STOREDIR/$PATID/$PLANTYPE/$PLANID

ln -s $PLANLOCATION $TEMPDIR
[ ! -d $OUTPUTDIR ] && mkdir -p $OUTPUTDIR
printf "Output Directory: $OUTPUTDIR \n" | tee -a $LOGFILE


PLANVERSION=$(head -n 1 "$PLANLOCATION/plan" | tail -n 1)
printf "Plan Version: $PLANVERSION \n" | tee -a $LOGFILE
if [ "$PLANVERSION" \< "006d101a" ]; then
    STUDYSET_OFFSET=6
else
    STUDYSET_OFFSET=7
fi
printf "Studyset offset: $STUDYSET_OFFSET \n" | tee -a $LOGFILE
XIOSTUDYID=$(head -n $STUDYSET_OFFSET "$PLANLOCATION/plan" | tail -n 1)
printf "XIO Study ID: $XIOSTUDYID \n" | tee -a $LOGFILE
STUDYINFO="$PATIENTLOCATION/anatomy/studyset/$XIOSTUDYID.info"
STUDY_UID=$(getCtStudyUid $STUDYINFO)
printf "Study UID: $STUDY_UID \n" | tee -a $LOGFILE
CT_SERIES_UID=$(getCtSeriesUid $STUDYINFO)
printf "CT Series UID: $CT_SERIES_UID \n" | tee -a $LOGFILE

SOPINSTUID_RTS="1.3.6.1.4.1.9590.100.1.1.$(head -c8 /dev/urandom| od -An -t o8 | sed 's/^\s//')"
printf "RTSTRUCT SOP Instance UID: $SOPINSTUID_RTS \n" | tee -a $LOGFILE
SOPINSTUID_RTP="1.3.6.1.4.1.9590.100.1.1.$(head -c8 /dev/urandom| od -An -t o8 | sed 's/^\s//')"
printf "RTPLAN SOP Instance UID: $SOPINSTUID_RTP \n" | tee -a $LOGFILE

$FOCUS/bin/output_dicom_rt -image $OUTPUTDIR/ $PATID $XIOSTUDYID $STUDY_UID
$FOCUS/bin/output_dicom_rt -ss $OUTPUTDIR/ $PATID $PLANID $SOPINSTUID_RTS $STUDY_UID
$FOCUS/bin/output_dicom_rt -permplan $OUTPUTDIR/ $PATID $PLANID $SOPINSTUID_RTP $STUDY_UID $SOPINSTUID_RTS

VERSION=`$FOCUS/bin/xio --v | cut -d' ' -f3`
DEMOGRAPHIC="$PATIENTLOCATION/demographic"
DOSEFILE="$PLANLOCATION/dose.1"
FILENAME="$OUTPUTDIR/DOSE.$PATID.$PLANID.dcm"

printf "RTDOSE filename: $FILENAME \n" | tee -a $LOGFILE

SWITCH=0
REFSOPUID=$SOPINSTUID_RTP	# Unused(?): REFSOPUID is taken from <STUDY>.info file if exporting DOSE and PLAN
APPLNAME="xioconverter"
$FOCUS/bin/DoseExport $APPLNAME $VERSION $DEMOGRAPHIC $STUDYINFO $DOSEFILE $FILENAME $SWITCH $STUDY_UID $REFSOPUID

rm -rf $TEMPDIR

EXPORTEDCSV="/tmp/exportedpatients.csv"
echo -n "$PATID,$PLANID,$PLANVERSION,$STUDY_UID,$CT_SERIES_UID,$SOPINSTUID_RTP,$SOPINSTUID_RTS," >> $EXPORTEDCSV

NROFPLANS=$(find $OUTPUTDIR -iname "*RTXPLAN*" | wc -l)
NROFCTS=$(find $OUTPUTDIR -iname "*CT*" | wc -l)
NROFSTRUCTS=$(find $OUTPUTDIR -iname "*SS*" | wc -l)
NROFDOSES=$(find $OUTPUTDIR -iname "*DOSE*" | wc -l)

if [ $NROFPLANS -gt 0 ] && [ $NROFCTS -gt 0 ] && [ $NROFSTRUCTS -gt 0 ] && [ $NROFDOSES -gt 0 ]; then
    echo "true">> $EXPORTEDCSV
else
    echo "false">> $EXPORTEDCSV
fi