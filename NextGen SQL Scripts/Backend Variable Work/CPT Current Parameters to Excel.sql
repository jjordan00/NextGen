--/****** Script for SelectTopNRows command from SSMS  ******/
--SELECT TOP 1000 [template_id]
--      ,[field]
--      ,[trig_name]
--      ,[action]
--      ,[trig_seq_no]
--      ,[trig_order]
--      ,[condition]
--      ,[parm1]
--      ,[parm2]
--      ,[enable_ind]
--      ,[create_timestamp]
--      ,[created_by]
--      ,[modify_timestamp]
--      ,[modified_by]
--      ,[comments]
--      ,[row_timestamp]
--  FROM [NGDevl].[dbo].[triggers]
--  where template_id = '5708' and field like '%cpt1%'
  
  --select * from trig_mf_xref where  template_id = '5708' and field_name like '%ccs1%'
  
 -- select * from templates where template_name like '%checkout_fin%'
 
 select tr.condition, tmx.field_value as 'Subjective' into #tempsub from triggers tr INNER JOIN
 trig_mf_xref tmx on tr.parm2 = tmx.trig_id where tr.template_id = '5708' and field like '%CPT1%' and tmx.field_name like '%txt_subj%'
 
 select tr.condition, tmx.field_value as 'CC'  into #tempcc from triggers tr INNER JOIN
 trig_mf_xref tmx on tr.parm2 = tmx.trig_id where tr.template_id = '5708' and field like '%CPT1%' and tmx.field_name like '%ccs1%'
 
 select tr.condition, tmx.field_value as 'Objective' into #tempobj from triggers tr INNER JOIN
 trig_mf_xref tmx on tr.parm2 = tmx.trig_id where tr.template_id = '5708' and field like '%CPT1%' and tmx.field_name like '%txt_obj%'
 
 select tr.condition, tmx.field_value as 'Assessment' into #tempassess from triggers tr INNER JOIN
 trig_mf_xref tmx on tr.parm2 = tmx.trig_id where tr.template_id = '5708' and field like '%CPT1%' and tmx.field_name like '%txt_ass%'
 
 select tr.condition, tmx.field_value as 'Plann' into #tempplan from triggers tr INNER JOIN
 trig_mf_xref tmx on tr.parm2 = tmx.trig_id where tr.template_id = '5708' and field like '%CPT1%' and tmx.field_name like '%txt_plan%'
 
 select tp.condition, ts.Subjective, tc.CC, tob.Objective, ta.Assessment, tp.Plann from #tempplan tp LEFT OUTER JOIN
 #tempsub ts on ts.condition = tp.condition LEFT OUTER JOIN
 #tempcc tc on tc.condition = tp.condition LEFT OUTER JOIN
 #tempobj tob on tob.condition = tp.condition LEFT OUTER JOIN
 #tempassess ta on ta.condition = tp.condition
 drop table #tempcc 
 drop table #tempplan 
 drop table #tempassess 
 drop table #tempobj 
 drop table #tempsub 