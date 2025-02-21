-- Function: eodata.find_landsat_datasets(date, date, numeric, numeric)

-- DROP FUNCTION eodata.find_landsat_datasets(date, date, numeric, numeric);

CREATE OR REPLACE FUNCTION eodata.find_landsat_datasets(acstart date, acstop date, cloud numeric, productid numeric)
  RETURNS SETOF eodata.dataset AS
$BODY$
declare
	result record;
begin
for result in
	select ia.*--, fp.the_geom 
	from eodata.dataset ia, eodata.image_footprint fp
	where 
		ia.gridid = fp.code 
		and ia.product = productid and
		overlaps(ia.acq_date,ia.acq_date,acstart::date,acstop::date)
		and ia.clouds <= cloud
		and (ia.sensor = 4 or  ia.sensor = 5) order by ia.acq_date
		
		loop
		return next result;
end loop;
return;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION eodata.find_landsat_datasets(date, date, numeric, numeric)
  OWNER TO madmex_user;
