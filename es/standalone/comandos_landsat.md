#Documentación técnica para la ejecución de procesos:

##Shells

###Landsat

####Descarga

*descarga_landsat.sh*

```
#!/bin/bash
#$1 es el sensor, $2 es el path, $3 es el row, $4 es el año
gsutil ls gs://earthengine-public/landsat/$1/$2/$3/|grep $4 > lista_landsat_tile_$2$3.txt
mkdir /results/landsat_tile_$2$3
for file in $(cat lista_landsat_tile_$2$3.txt);do
/usr/local/bin/gsutil cp -n $file /results/landsat_tile_$2$3/
done;
```

####Preprocesamiento

*ledaps.sh*

```
#!/bin/bash
#$1 es la ruta con los datos en forma .tar.bz
#$2 es la ruta al ancillary data
destiny=/results
name=$(basename $1)
basename=$(echo $name|sed -n 's/\(L*.*\).tar.bz/\1/;p')
dir=$destiny/$basename
mkdir -p $dir
cp $1 $dir
year=$(echo $name|sed -nE 's/L[A-Z][4-7][0-9]{3}[0-9]{3}([0-9]{4}).*.tar.bz/\1/p')
cp $2/CMGDEM.hdf $dir
cp $2/L5_TM/gold.dat $dir
cp $2/L5_TM/gnew.dat $dir
cp $2/L5_TM/gold_2003.dat $dirmkdir -p $dir/EP_TOMS && cp -r $2/EP_TOMS/ozone_$year $dir/EP_TOMS
mkdir -p $dir/REANALYSIS && cp -r $2/REANALYSIS/RE_$year $dir/REANALYSIS
cd $dir && tar xvf $name 
metadata=$(ls $dir|grep -E ^L[A-Z]?[4-7][0-9]{3}[0-9]{3}.*_MTL.txt)
metadataxml=$(echo $metadata|sed -nE 's/(L.*).txt/\1.xml/p')
export LEDAPS_AUX_DIR=$(pwd)
cd $dir && $BIN/convert_lpgs_to_espa --mtl=$metadata --xml=$metadataxml
cd $dir && $BIN/do_ledaps.csh $metadataxml
#cd $dir && $BIN/convert_espa_to_gtif --xml=$metadataxml --gtif=lndsr.$basename.tif 
cd $dir && $BIN/convert_espa_to_hdf --xml=$metadataxml --hdf=lndsr.$basename.hdf --del_src_files
mv lndsr.$(echo $basename)_MTL.txt lndsr.$(echo $basename)_metadata.txt 
mv lndcal.$(echo $basename)_MTL.txt lndcal.$(echo $basename)_metadata.txt 
cp lndsr.$(echo $basename).hdf lndcal.$(echo $basename).hdf
cp lndsr.$(echo $basename)_hdf.xml lndcal.$(echo $basename)_hdf.xml
rm $dir/$name
rm -r $dir/CMGDEM.hdf
rm -r $dir/EP_TOMS/
rm -r $dir/REANALYSIS/

```

*ledaps_antes_2012.sh*

```
#!/bin/bash
#Entrada: $1 es la ruta al archivo tar, $2 es la ruta al ancillary data en el comando de docker
destiny=/results
filename=$(basename $1)
newdir=$(echo $filename | sed -n 's/\(L*.*\).tar.bz/\1/;p')
dir=$destiny/$newdir
mkdir -p $dir
cp $1 $dir
cd $dir && tar xvf $filename
#LEDAPS
year=$(echo $filename|sed -nE 's/L[A-Z][4-7][0-9]{3}[0-9]{3}([0-9]{4}).*/\1/p')
cp $2/CMGDEM.hdf $dir
cp $2/L5_TM/gold.dat $dir
cp $2/L5_TM/gnew.dat $dir
cp $2/L5_TM/gold_2003.dat $dir
mkdir $dir/EP_TOMS && cp -r $2/EP_TOMS/ozone_$year $dir/EP_TOMS
mkdir $dir/REANALYSIS && cp -r $2/REANALYSIS/RE_$year $dir/REANALYSIS
metadata=$(ls $dir|grep -E ^L[A-Z]?[4-7][0-9]{3}[0-9]{3}.*_MTL.txt)
#cd $dir && /usr/local/bin/ledapsSrc/bin/do_ledaps.csh $metadata
cd $dir && $BIN/do_ledaps.csh $metadata
rm $dir/$filename
rm -rf $dir/CMGDEM.hdf
rm -rf $dir/EP_TOMS
rm -rf $dir/REANALYSIS
rm -r $dir

```

*ledaps_landsat8.sh*

```
#!/bin/bash
#Entrada: $1 es la ruta con los datos en forma .tar.bz, $2 es la ruta a los datos auxiliares en docker
#Para el servidor http://e4ftl01.cr.usgs.gov $3 es el usuario y $4 es su password
#Para el servidor ladssci.nascom.nasa.gov $5 es el usuario y $6 es su password
destiny=/results
name=$(basename $1)
basename=$(echo $name|sed -n 's/\(L*.*\).tar.bz/\1/;p')
dir=$destiny/$basename
mkdir -p $dir
cp $1 $dir
cd $dir
year=$(echo $name|sed -nE 's/L[A-Z]?[5-8][0-9]{3}[0-9]{3}([0-9]{4}).*.tar.bz/\1/p')
day_of_year=$(echo $name|sed -nE 's/L[A-Z]?[5-8][0-9]{3}[0-9]{3}[0-9]{4}([0-9]{1,3}).*.tar.bz/\1/p')
year_month_day=$(date -d "$year-01-01 +$day_of_year days -1 day" "+%Y.%m.%d")
if [ ! -e $2/LADS/$year/L8ANC$year$day_of_year.hdf_fused ];
then
  #download cmg products
  echo "download cmg products"
  root=http://e4ftl01.cr.usgs.gov
  mod09=MOLT/MOD09CMG.006
  myd09=MOLA/MYD09CMG.006
  #date_acquired=$(cat $metadata|grep 'DATE_ACQUIRED'|cut -d'=' -f2|sed -n -e "s/-/./g" -e "s/ //p")
  date_acquired=$year_month_day
  echo $date_acquired
  echo "$root/$mod09/$date_acquired"
  if [ $(wget -L --user=$3 --password=$4 -qO - $root/$mod09/$date_acquired/|grep "MOD.*.hdf\""|wc -l) -gt 1 ]; then echo "Too many files for MOD09CMG"; else
    wget -L --user=$3 --password=$4 --load-cookies ~/.cookies --save-cookies ~/.cookies -A hdf,xml,jpg -nd -r -l1 --no-parent "$root/$mod09/$date_acquired/"
  fi
  if [ $(wget -L --user=$3 --password=$4 -qO - $root/$myd09/$date_acquired/|grep "MYD.*.hdf\""|wc -l) -gt 1 ]; then echo "Too many files for MYD09CMG"; else
    wget -L --user=$3 --password=$4 --load-cookies ~/.cookies --save-cookies ~/.cookies -A hdf,xml,jpg -nd -r -l1 --no-parent "$root/$myd09/$date_acquired/"
  fi
  #download cma products
  echo "download cma products"
  root=ftp://$5:$6@ladssci.nascom.nasa.gov
  mod09cma=6/MOD09CMA
  myd09cma=6/MYD09CMA
  if [ $(wget -qO - $root/$mod09cma/$year/$day_of_year/|grep "MOD09CMA.*.hdf\""|wc -l) -gt 1 ]; then echo "Too many files for MOD09CMA"; else
    wget -A hdf -nd -r -l1 --no-parent "$root/$mod09cma/$year/$day_of_year/"
  fi
  if [ $(wget -qO - $root/$mod09cma/$year/$day_of_year/|grep "MOD09CMA.*.hdf\""|wc -l) -gt 1 ]; then echo "Too many files for MYD09CMA"; else
    wget -A hdf -nd -r -l1 --no-parent "$root/$myd09cma/$year/$day_of_year/"
  fi
  #combine aux data
  terra_cmg=$(ls .|grep MOD09CMG.*.hdf$)
  echo $terra_cmg
  terra_cma=$(ls .|grep MOD09CMA.*.hdf$)
  echo $terra_cma
  aqua_cma=$(ls .|grep MYD09CMA.*.hdf$)
  aqua_cmg=$(ls .|grep MYD09CMG.*.hdf$)
  echo $aqua_cma
  echo $aqua_cmg
  $BIN/combine_l8_aux_data --terra_cmg=$terra_cmg --terra_cma=$terra_cma --aqua_cmg=$aqua_cmg --aqua_cma=$aqua_cma --output_dir=$PWD
  #copy the combine aux data for future processes
  anc=$(ls .|grep ANC)
  mkdir -p $2/LADS/$year
  cp $anc $2/LADS/$year
  #move the combine aux data
  mkdir -p LADS/$year
  mv $anc LADS/$year
  #else
else
  echo "found fused file, not downloading"
  mkdir -p LADS/$year
  anc=$(ls $2/LADS/$year|grep ".*$year$day_of_year")
  cp $2/LADS/$year/$anc LADS/$year/
fi

#surface reflectances:
echo "Beginning untar"
#untar file
tar xvf $name
echo "finish untar"
metadata=$(ls .|grep -E ^L[A-Z]?[5-8][0-9]{3}[0-9]{3}.*_MTL.txt)
metadataxml=$(echo $metadata|sed -nE 's/(L.*).txt/\1.xml/p')
echo $metadata
echo $metadataxml
echo "finish identification of metadata"
$BIN/convert_lpgs_to_espa --mtl=$metadata --xml=$metadataxml
#check if the next line is important for the analysis
#$BIN/create_land_water_mask --xml=$metadataxml
cp -r $2/LDCMLUT .
cp $2/ratiomapndwiexp.hdf .
cp $2/CMGDEM.hdf .
echo "Surface reflectance process"
$BIN/lasrc --xml=$metadataxml --aux=$anc --verbose --write_toa
$BIN/convert_espa_to_hdf --xml=$metadataxml --hdf=lndsr.$basename.hdf --del_src_files
cp lndsr.$(echo $basename).hdf lndcal.$(echo $basename).hdf
cp lndsr.$(echo $basename)_hdf.xml lndcal.$(echo $basename)_hdf.xml
```

*fmask.sh*

```
#!/bin/bash
#$1 es la ruta con los datos en forma .tar.bz
filename=$(basename $1)
newdir=$(echo $filename | sed -n 's/\(L*.*\).tar.bz/\1/;p')
path=$(echo $PWD)
new_filename=$path/$filename
mkdir -p $path/$newdir
cd $path/$newdir
tar xvjf $new_filename
gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img L*_B[1,2,3,4,5,7].TIF
gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img L*_B6_VCID_?.TIF
fmask_usgsLandsatSaturationMask.py -i ref.img -m *_MTL.txt -o saturationmask.img
fmask_usgsLandsatTOA.py -i ref.img -m *_MTL.txt -o toa.img
fmask_usgsLandsatStacked.py -t thermal.img -a toa.img -m *_MTL.txt -s saturationmask.img -o cloud.img
gdal_translate -of ENVI cloud.img $(echo $newdir)_MTLFmask
```
*fmask_L8754.sh*

```
#!/bin/bash
#$1 es la ruta con los datos
filename=$(basename $1)
path=$(echo $PWD)

if [[ -d $filename ]]; then
    cd $path/$filename
    f_name=$filename
    sat=${filename:0:3}
elif [[ -f $filename ]]; then
    newdir_tar=$(echo $filename | sed -n 's/\(L*.*\).tar.bz/\1/;p')
    f_name=$newdir_tar
    mkdir -p $path/$newdir_tar
    cd $path/$newdir_tar
    tar xvjf $path/$filename
    sat=${newdir_tar:0:3}
else
    echo "Input file is not valid"
    exit 1
fi

if [ $sat == "LE7" ]
then
  echo "Landsat 7"
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img L*_B[1,2,3,4,5,7].TIF
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img L*_B6_VCID_?.TIF
elif [ $sat == "LT5" ] || [ $sat=="LT4" ]
then
  echo "Landsat 5 or 4"
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img L*_B[1,2,3,4,5,7].TIF
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img L*_B6.TIF
elif [ $sat == "LC8" ]
then
  echo "Landsat 8"
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img LC8*_B[1-7,9].TIF
  gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img LC8*_B1[0,1].TIF
else 
  echo "unknown satellite"
  exit
fi

fmask_usgsLandsatSaturationMask.py -i ref.img -m *_MTL.txt -o saturationmask.img
fmask_usgsLandsatTOA.py -i ref.img -m *_MTL.txt -o toa.img
fmask_usgsLandsatStacked.py -t thermal.img -a toa.img -m *_MTL.txt -s saturationmask.img -o cloud.img
gdal_translate -of ENVI cloud.img $(echo $f_name)_MTLFmask
```

*fmask_ls8.sh*

```
#!/bin/bash
#$1 es la ruta con los datos en forma .tar.bz
filename=$(basename $1)
newdir=$(echo $filename | sed -n 's/\(L*.*\).tar.bz/\1/;p')
path=$(echo $PWD)
new_filename=$path/$filename
mkdir -p $path/$newdir
cd $path/$newdir
tar xvjf $new_filename
gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img L[C-O]8*_B[1-7,9].TIF
gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img L[C-O]8*_B1[0,1].TIF
fmask_usgsLandsatSaturationMask.py -i ref.img -m *_MTL.txt -o saturationmask.img
fmask_usgsLandsatTOA.py -i ref.img -m *_MTL.txt -o toa.img
fmask_usgsLandsatStacked.py -t thermal.img -a toa.img -m *_MTL.txt -s saturationmask.img -o cloud.img
gdal_translate -of ENVI cloud.img $(echo $newfilename)_MTLFmask
```

####Ingestión

*data_ingestion.sh*

```
#!/bin/bash
#$1 es la ruta del archivo .tar.bz a ingestar
filename=$(basename $1)
newdir=$(echo $filename | sed -n 's/\(L*.*\).tar.bz/\1/;p')
folder=/results
new_filename=$folder/$filename
mkdir -p $folder/$newdir
cp $1 $folder/$newdir
cd $folder/$newdir
tar xvjf $filename
source /results/variables.txt
/usr/bin/python $MADMEX/interfaces/cli/madmex_processing.py Ingestion --input_directory $folder/$newdir

```

*data_ingestion_folder.sh*

```
#!/bin/bash
#$1 es la ruta del archivo a ingestar

source /results/variables.txt
/usr/bin/python $MADMEX/interfaces/cli/madmex_processing.py Ingestion --input_directory $1

```

####Preprocesamiento e ingestión

*preprocesamiento_e_ingestion_landsat_no_8.sh*

```
#!/bin/bash
#$1 es la ruta a los datos de landsat .tar.bz
#$2 es la ruta al ancillary data de LEDAPS
#$3 es la ruta al repositorio CONABIO/madmex-v2
#$4 es la ruta al archivo configuration.ini
#$5 es la ruta a la carpeta eodata

name=$(basename $1)
basename=$(echo $name|sed -n 's/\(L*.*\).tar.bz/\1/;p')
path=$(echo $PWD)
dir=$path/$basename
mkdir -p $dir
cp $1 $dir
cd $dir && tar xvf $name
#LEDAPS:
year=$(echo $name|sed -nE 's/L[A-Z][4-7][0-9]{3}[0-9]{3}([0-9]{4}).*/\1/p')

cp $2/CMGDEM.hdf $dir
cp $2/L5_TM/gold.dat $dir
cp $2/L5_TM/gnew.dat $dir
cp $2/L5_TM/gold_2003.dat $dirmkdir $dir/EP_TOMS && cp -r $2/EP_TOMS/ozone_$year $dir/EP_TOMS
mkdir $dir/REANALYSIS && cp -r $2/REANALYSIS/RE_$year $dir/REANALYSIS
metadata=$(ls $dir|grep -E ^L[A-Z]?[4-7][0-9]{3}[0-9]{3}.*_MTL.txt)
metadataxml=$(echo $metadata|sed -nE 's/(L.*).txt/\1.xml/p')
echo "Working directory:"
echo $(pwd)
docker $(docker-machine config default) run --rm -e metadata=$metadata -e metadataxml=$metadataxml -v $(pwd):/opt/ledaps -v $(pwd):/data -v $(pwd)/:/results madmex/ledaps:latest /bin/sh -c '$BIN/convert_lpgs_to_espa --mtl=$metadata --xml=$metadataxml'
docker $(docker-machine config default) run --rm -e metadataxml=$metadataxml -v $(pwd):/opt/ledaps -v $(pwd):/data -v $(pwd)/:/results madmex/ledaps:latest /bin/sh -c '$BIN/do_ledaps.csh $metadataxml'
#docker $(docker-machine config default) run --rm -e metadataxml=$metadataxml -e basename=$basename -v $(pwd):/opt/ledaps -v $(pwd):/data -v $(pwd)/:/results madmex/ledaps:latest /bin/sh -c '$BIN/convert_espa_to_gtif --xml=$metadataxml --gtif=lndsr.$basename.tif'
docker $(docker-machine config default) run --rm -e metadataxml=$metadataxml -e basename=$basename -v $(pwd):/opt/ledaps -v $(pwd):/data -v $(pwd)/:/results madmex/ledaps:latest /bin/sh -c '$BIN/convert_espa_to_hdf --xml=$metadataxml --hdf=lndsr.$basename.hdf --del_src_files'
mv lndsr.$(echo $basename)_MTL.txt lndsr.$(echo $basename)_metadata.txt 
mv lndcal.$(echo $basename)_MTL.txt lndcal.$(echo $basename)_metadata.txt 
cp lndsr.$(echo $basename).hdf lndcal.$(echo $basename).hdf
cp lndsr.$(echo $basename)_hdf.xml lndcal.$(echo $basename)_hdf.xml
rm $name
rm -rf CMGDEM.hdf
rm -rf EP_TOMS
rm -rf REANALYSIS

#Fmask:
docker $(docker-machine config default) run --rm -v $(pwd):/data madmex/python-fmask gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o ref.img L*_B[1,2,3,4,5,7].TIF
docker $(docker-machine config default) run --rm -v $(pwd):/data madmex/python-fmask gdal_merge.py -separate -of HFA -co COMPRESSED=YES -o thermal.img L*_B6_VCID_?.TIF
docker $(docker-machine config default) run --rm -v $(pwd):/data madmex/python-fmask fmask_usgsLandsatSaturationMask.py -i ref.img -m *_MTL.txt -o saturationmask.img
docker $(docker-machine config default) run --rm -v $(pwd):/data madmex/python-fmask fmask_usgsLandsatTOA.py -i ref.img -m *_MTL.txt -o toa.img
docker $(docker-machine config default) run --rm -v $(pwd):/data madmex/python-fmask fmask_usgsLandsatStacked.py -t thermal.img -a toa.img -m *_MTL.txt -s saturationmask.img -o cloud.img
docker $(docker-machine config default) run -v $(pwd):/data madmex/python-fmask gdal_translate -of ENVI cloud.img $(echo $basename)_MTLFmask

#Ingest
cd $path
MADMEX=/LUSTRE/MADMEX/code 
MRV_CONFIG=$MADMEX/resources/config/configuration.ini
PYTHONPATH=$PYTHONPATH:$MADMEX
MADMEX_DEBUG=True
MADMEX_TEMP=/services/localtemp/temp
docker $(docker-machine config default) run -e MADMEX=$MADMEX -e MRV_CONFIG=$MRV_CONFIG -e PYTHONPATH=$PYTHONPATH -e MADMEX_DEBUG=$MADMEX_DEBUG -e MADMEX_TEMP=$MADMEX_TEMP --rm -v $3:/LUSTRE/MADMEX/code -v $4:/LUSTRE/MADMEX/code/resources/config -v $5:/LUSTRE/MADMEX/eodata -v $(pwd):/results madmex/ws /usr/bin/python $MADMEX/interfaces/cli/madmex_processing.py Ingestion --input_directory /results/$basename

```

####Clasificación

*clasificacion_landsat.sh*

```
#!/bin/bash
#$1 es la fecha de inicio, $2 es la fecha de fin, $3 es el máximo porcentaje de nubes permitido
#$4 es el pathrow, $5 es la ruta al conjunto de entrenamiento
#$6 es 1 si se quiere hacer eliminación de datos atípicos, 0 en caso contrario

source /results/variables.txt
/usr/bin/python $MADMEX/interfaces/cli/madmex_processing.py LandsatLccWorkflowV3FilesAfter2012 --start_date_string $1 --end_date_string $2 --max_cloud_percentage $3 --landsat_footprint $4 --training_url $5 --outlier $6
```
####Postprocesamiento de clasificación

*postprocesamiento_clasificacion_landsat.sh*

```
#!/bin/bash
#$1 es el folder que contiene los resultados de clasificación, $2 es el archivo ESRI que contiene los tiles de la región
#$3 es el nombre de la columna del archivo ESRI $2, $4 es el folder donde estarán los resultados que ayudan al postprocesamiento
#$5 es el nombre del archivo resultado del postprocesamiento
source /results/variables.txt
/usr/bin/python $MADMEX/interfaces/cli/madmex_processing.py LandsatLccPostWorkflow --lccresultfolder $1 --footprintshape $2 --tileidcolumnname $3 --workingdir $4 --outfile $5
```


