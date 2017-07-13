export FOCUS=/FOCUS
export RTOP=$FOCUS/rtp1/1
export FOCUS_CLINIC_ID="RESEARCH"
export DISPLAY=":0"
export ERR_TABLE="$FOCUS/bin/../disppage/U_rtperr_tab"
export MSG_TABLE="$FOCUS/bin/../disppage/U_rtpmsg_tab"

LOGFILE=/tmp/xiotodicom.log
PRIORITYLIST=$(cat /opt/DicomExport4XiO/prioritylist.txt)
TARLOC=/home/timh/tarfiles
printf "Tar file location: $TARLOC \n"
DATALOC=$RTOP/patient
STOREDIR=/tmp/dicom

for PATIENTID in $PRIORITYLIST; do
    if [ ! -f "$TARLOC/$PATIENTID.tgz" ]; then
        printf "$PATIENTID not in folder. \n" | tee -a $LOGFILE
    else
        printf "unzipping Tar file: $PATIENTID.tgz \n" | tee -a $LOGFILE
        gzip -dc $TARLOC/$PATIENTID.tgz| tar xf - -C $DATALOC    
    fi
done

printf "Data location: $DATALOC\n" | tee -a $LOGFILE
PATIENTLIST=$(find $DATALOC -type d -maxdepth 1 -mindepth 1 | sed 's!.*/!!')
printf "PATIENTLIST:\n$PATIENTLIST\n" | tee -a $LOGFILE

for PATIENTID in $PATIENTLIST; do
    printf "Exporting Patient ID: $PATIENTID \n" | tee -a $LOGFILE
    PATIENTLOCATION=$DATALOC/$PATIENTID

    PLANFOLDERLIST=$(find $PATIENTLOCATION -type d -name plan) 
    MONPLANFOLDERLIST=$(find $PATIENTLOCATION -type d -name monplan)
    EMPTYPLANFOLDERLIST=$(find $PATIENTLOCATION -type d -name plan -empty)
    EMPTYMONPLANFOLDERLIST=$(find $PATIENTLOCATION -type d -name monplan -empty)

    for PLANLOCATION in $EMPTYPLANFOLDERLIST; do
        printf "empty plan folder: $PLANLOCATION \n" | tee -a $LOGFILE
    done

    for PLANLOCATION in $EMPTYMONPLANFOLDERLIST; do
        printf "empty monplan folder: $PLANLOCATION \n" | tee -a $LOGFILE
    done

    for PLANFOLDER in $PLANFOLDERLIST; do
        for PLANLOCATION in $(find $PLANFOLDER -type d -maxdepth 1 -mindepth 1); do
            PLANID=$(echo $PLANLOCATION | sed 's:/plan:\;:g' | cut -d';' -f2 | cut -d';' -f1 | cut -d'/' -f2)
            printf "PLANID: $PLANID \n" | tee -a $LOGFILE
            TEMPDIR=$RTOP/temp/$PLANID
            sh writexioplan.sh $FOCUS $STOREDIR $TEMPDIR $PATIENTLOCATION $PLANLOCATION $PATIENTID $PLANID "plan" $LOGFILE
        done
    done

    for PLANFOLDER in $MONPLANFOLDERLIST; do
        for PLANLOCATION in $(find $PLANFOLDER -type d -maxdepth 1 -mindepth 1); do
            PLANID=$(echo $PLANLOCATION | sed 's:/monplan:\;:g' | cut -d';' -f2 | cut -d';' -f1 | cut -d'/' -f2)
            printf "PLANID: $PLANID \n" | tee -a $LOGFILE
            TEMPDIR=$RTOP/temp/$PLANID
            sh writexioplan.sh $FOCUS $STOREDIR $TEMPDIR $PATIENTLOCATION $PLANLOCATION $PATIENTID $PLANID "monplan" $LOGFILE
        done
    done
done