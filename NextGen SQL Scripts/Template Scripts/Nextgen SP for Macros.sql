USE [NGDevl]
GO
/****** Object:  StoredProcedure [dbo].[ngkbm_td_save]    Script Date: 09/03/2013 13:24:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER PROCEDURE [dbo].[ngkbm_td_save]
 @enterprise_id char(5),
 @practice_id char(4),
 @person_id uniqueidentifier,
 @enc_id uniqueidentifier,
 @all_templates_ind int,  --Comes from ngkbm_default_save_.save_which_templates 0= All Templates, 1 = current template only, 2 = selected templates
 @templates varchar(1000),  --List of templates we're saving.
 @set_name varchar(256),
 @provider_id varchar(36),
 @user_id int,
 @category varchar(100),
 @specialty varchar(25)

 AS


/****************************************************************************************************
[- purpose:  Saves a Template Default Set from a Template  -]
[- details:  dbpicklist that looks for all templates that are "default ready", all templates that use quick save -]
[- type:     KBM -]

[- created:  20070122-4454 -]
[- modified: 20070118-4454 : Added full lookup of provider name. -]
[- modified: 20100527-4D4D : updated subquery to look for the executing_set_id fields and not the kbm_meta label -]
[- modified: 20101215-4D4D : updated to work with quick save of PE grid values -]
[- modified: 20110721-4D4D : updated to allow for multiple dx codes for AIP quick notes -]
[- modified: 20111011-4D4D : updates for saving derm grid in quick save -]
[- modified: 20111130-4D4D : updates for saving HPI grid in quick save -]
[- modified: 20111220-4D4D : updates for fts_soap full exams. grab only related templates for full exams (hpi, ros, pe) -]
[- modified: 20120106-4D4D : added save for physical_exam_findings_ for PE categories -]
[- modified: 20120106-4D4D : updated to look at physical_exam_findings_ only if category = PE and @all_templates_ind = 0 -]
[- modified: 20120111-4D4D : added ngkbm_default_audit functionality if multiple defaults are used -]

*****************************************************************************************************/

DECLARE @seq_no varchar(36)
DECLARE @template_id int


--Get latest seq_no from ngkbm_defult_sets_ table with the name of the set
SELECT TOP 1 @seq_no=CONVERT(varchar(36),seq_no)
from ngkbm_default_sets_
where set_name=@set_name
and set_type='SAVED_TEMPLATES'
order by create_timestamp desc

IF @seq_no is null return

--Case with all templates in an encounter that can be saved.
IF @all_templates_ind=0 BEGIN

	DECLARE @full_exam_templates table (template_name varchar(35), template_id int)
	DECLARE @visited_templates table (template_id int)

	--populate temp table with all templates that are "defaults ready" marked from this encounter.
	insert into @visited_templates (template_id)
	select distinct template_audit.template_id
	from template_audit
	where template_audit.enc_id=@enc_id
		and template_audit.enterprise_id=@enterprise_id
		and template_audit.practice_id=@practice_id
		and template_audit.person_id=@person_id
		and template_audit.template_id in
			(select distinct template_id
			from template_fields
			where table_name = 'ngkbm_default_save_'
				and field_name = 'executing_set_id'
				and template_id not in (
					select template_id
					from templates
					where (template_name = 'ngkbm_default_save' or alias_template = 'ngkbm_default_save')
					)
			)

--check the default audit table for any templates that are default-ready and not actually visited on the encounter
 if @category in ('HPI Full Exam', 'PE Full Exam', 'ROS Full Exam', 'Full Exam')
 BEGIN
		
	if exists (select 1 from ngkbm_default_audit where enc_id = @enc_id)
	insert into @visited_templates (template_id)
	select distinct template_id from ngkbm_default_audit where enc_id = @enc_id	
	and template_id not in (select template_id from @visited_templates)
	
	--else

	insert into ngkbm_default_audit (enterprise_id, practice_id, person_id, enc_id, template_id, set_id, kbm_ind, created_by)
	select distinct @enterprise_id, @practice_id, @person_id, @enc_id, template_id, @seq_no, 'N', @user_id
	from @visited_templates
	where template_id not in (select template_id from ngkbm_default_audit where enc_id = @enc_id)
	
 END

 --build temp table of exam-specific templates for saving individual sections
 if @category in ('HPI Full Exam', 'PE Full Exam', 'ROS Full Exam')
 BEGIN

	if @category = 'HPI Full Exam' begin

	insert into @full_exam_templates (template_name)
	select distinct template_name from ngkbm_custom_nav_setup_ where practice_id = @practice_id and filter = 'hpi'

	end
	if @category = 'ROS Full Exam' begin

	insert into @full_exam_templates (template_name)
	select distinct txt_template_name from ngkbm_foundtn_contnt_items_
	where (txt_practice_id = @practice_id or isnull(txt_practice_id,'') = '') and (txt_content_type = 'ros' or txt_content_type = 'ros custom')

	end
	if @category = 'PE Full Exam' begin

	insert into @full_exam_templates (template_name)
	select distinct template_name from ngkbm_custom_nav_setup_ where practice_id = @practice_id and filter = 'pe'

	end

	update @full_exam_templates
	set template_id = t.template_id
	from templates t join @full_exam_templates f on t.template_name = f.template_name

	delete from @visited_templates
	where template_id not in (select isnull(template_id,0) from @full_exam_templates)

 END


 DECLARE C CURSOR FOR select distinct template_id from @visited_templates
 OPEN C

 FETCH C INTO @template_id

 WHILE (@@FETCH_STATUS=0) BEGIN

  EXEC ngkbm_td_values_add @enterprise_id, @practice_id, @person_id, @enc_id, @seq_no, @template_id, @user_id

 FETCH C INTO @template_id
 END
 CLOSE C
 DEALLOCATE C
END
ELSE IF @all_templates_ind=1 OR @all_templates_ind=2 AND @templates<>'' BEGIN

 SET @template_id=''

 --Tokenize the string @templates to get list of templates
 DECLARE C CURSOR FOR
 select distinct template_id from templates where template_name in (select * from fnSplit(@templates,','))

 OPEN C

 FETCH C INTO @template_id

 WHILE (@@FETCH_STATUS=0) BEGIN

  EXEC ngkbm_td_values_add @enterprise_id, @practice_id, @person_id, @enc_id, @seq_no, @template_id, @user_id

 FETCH C INTO @template_id
 END

 CLOSE C
 DEALLOCATE C

END

--SETUP Provs table.
DECLARE @last_name varchar(100)
DECLARE @first_name varchar(100)
DECLARE @middle_name varchar(50)

select @last_name=last_name, @first_name=first_name, @middle_name=middle_name from provider_mstr where provider_id=@provider_id

 INSERT INTO ngkbm_default_provs_ (site_id, seq_no, created_by, create_timestamp, modified_by, modify_timestamp, first_name, last_name, middle_init,
 not_ind, provider_id, set_id)
 VALUES
 ('000', NEWID(), @user_id, CURRENT_TIMESTAMP, @user_id, CURRENT_TIMESTAMP, @first_name, @last_name, @middle_name,
 0,@provider_id, @seq_no)

--collect grid information for HPI, PE, ADP when Full Exams are used on SOAP
if (@category = 'HPI Full Exam' or @category = 'Full Exam')
Begin

 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, field_name, set_id, set_value, table_name, grid_ind, display_order, grid_type)

 select '000', newid(), @user_id, @user_id, txt_template_name, @seq_no, txt_note, txt_chief_complaint, '1', cc_number, 'HPI'
 from HOPI_ex_
 where enterprise_id = @enterprise_id
 and practice_id = @practice_id
 and person_id = @person_id
 and enc_id = @enc_id

end

if (@category = 'PE Full Exam' or @category = 'Full Exam' or (@category = 'PE' and @all_templates_ind = 0))
Begin

 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, field_name, set_id, set_value, table_name, sql_count, sql_insert,
 sql_update, grid_ind, display_order, exam_result, exam_system, source_flag, exam_name, grid_type)
 select '000', newid(), @user_id, @user_id, '', @seq_no, ExamFindings, template_name, '', '',
 '', '1', DisplayOrder, ExamResult, SystemExamed, 'SP', ExamName, 'PE'
 from PhysExamExtPop_
 where enterprise_id = @enterprise_id
 and practice_id = @practice_id
 and person_id = @person_id
 and enc_id = @enc_id
 and isnull(ExamFindings, '')<>''

 if exists (select 1 from physical_exam_findings_
 where enterprise_id = @enterprise_id
 and practice_id = @practice_id
 and person_id = @person_id
 and enc_id = @enc_id  )

 begin

	 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, set_id,
	 field_name, set_value, exam_name, exam_result, display_order, exam_system, grid_ind, grid_type)
	 select '000', newid(), @user_id, @user_id, @seq_no,
	 txt_exam_element, txt_exam_findings, txt_exam_name, txt_exam_result, txt_sort_order, txt_system_examed, '1', 'PE2'
	 from physical_exam_findings_
	 where enterprise_id = @enterprise_id
	 and practice_id = @practice_id
	 and person_id = @person_id
	 and enc_id = @enc_id

 end

end

-- add dx code selection for Quick Save
if (@category = 'AIP Full Exam' or @category = 'Full Exam')
Begin

 if @specialty = 'DERM' begin

 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, set_id, grid_ind, grid_type,
 exam_system, table_name, field_name, set_value, sql_insert, sql_update)

 select '000', newid(), @user_id, @user_id, @seq_no, '1', 'DERM',
 txt_assessment, txt_icd9_code,
 txt_assess_loc,
 txt_exam_desc,
 txt_tx_summary,
 txt_tx_summary02
 from derm_exam_tx_grid_
 where enterprise_id = @enterprise_id
 and practice_id = @practice_id
 and person_id = @person_id
 and enc_id = @enc_id

 end
 else begin

 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, set_id, set_value, grid_ind, aip_code,
 aip_priority_display, dx_code_id, dx_unique_id, enc_dx_priority, icd_code_id, grid_type)

 select '000', newid(), @user_id, @user_id, @seq_no, txt_description, '1',
 txt_aip, txt_aip_priority_display, txt_diagnosis_code_id, aip.txt_diagnosis_uniq_id, txt_enc_dx_priority, txt_icd9cm_code_id, 'AIP'
 from assessment_impression_plan_ aip
 where aip.enterprise_id = @enterprise_id
 and aip.practice_id = @practice_id
 and aip.person_id = @person_id
 and aip.enc_id = @enc_id

 insert into ngkbm_default_values_ (site_id, seq_no, created_by, modified_by, set_id, grid_ind, grid_type, aip_impression_type,
 exam_system, table_name, dx_code_id, aip_impression_text, set_value, aip_impression_text_id,
 field_name, exam_name )

 select '000', newid(), @user_id, @user_id, @seq_no, '1', 'ORD', actClass, actCode, actDiagnosis, actDiagnosisCode, actTextDisplay,
 actTextDispDoc, orderedByKey, orderedBy, actSubClass
 from order_ where actMood = 'ORD' and encounterID = cast(@enc_id as varchar(36))

 end
end

