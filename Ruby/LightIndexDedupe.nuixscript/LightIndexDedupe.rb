script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

require "thread"
require "digest"

dialog = TabbedCustomDialog.new("Light Index Dedupe")

main_tab = dialog.addTab("main_tab","Main")
main_tab.appendHeader("Selected Items: #{$current_selected_items.size}")
main_tab.appendTextField("item_set_name","Item Set Name","")
main_tab.appendTextField("batch_name","Batch Name","")

main_tab.appendHeader("Deduplication comparison values:")
main_tab.appendCheckBox("include_name","Use Name",true)
main_tab.appendCheckBox("include_file_size","Use 'File Size'",true)
main_tab.appendCheckBox("include_file_modified","Use 'File Modified' Date",true)
main_tab.appendCheckBox("include_item_date","Use Item Date",true)
main_tab.appendCheckBox("include_content_text","Use Content Text",false)

main_tab.appendHeader("Date Accuracy")
main_tab.appendRadioButton("accuracy_millisecond","Date Accuracy to Millisecond (yyyy/MM/dd HH:mm:ss.SSS)","date_accuracy",true)
main_tab.appendRadioButton("accuracy_second","Date Accuracy to Second (yyyy/MM/dd HH:mm:ss)","date_accuracy",false)
main_tab.appendRadioButton("accuracy_minute","Date Accuracy to Minute (yyyy/MM/dd HH:mm)","date_accuracy",false)

main_tab.appendHeader("Item Settings")
main_tab.appendCheckBox("by_family","Dedupe By Family",true)
main_tab.appendCheckBox("pull_in_families","Pull in Family Members of Selected Items",true)

annotations_tab = dialog.addTab("annotations_tab","Annotations")
annotations_tab.appendCheckableTextField("record_digest_input",false,"digest_input_field","LightIndexDedupeInput","Record concatenated input value as")
annotations_tab.appendCheckableTextField("record_digest",false,"digest_field","LightIndexDedupeMD5","Record deduplication MD5 as")

dialog.validateBeforeClosing do |values|
	if !values["include_name"] && !values["include_file_size"] && !values["include_file_modified"] && !values["include_content_text"] &&
		!values["include_item_date"]
		CommonDialogs.showWarning("Please select at least one value to use for deduplication comparison.")
		next false
	end

	# Confirm item set name is not blank
	if values["item_set_name"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Item Set Name'")
		next false
	end

	# Confirm it is okat to add items to existing item set if the given item set
	# name already exists
	item_set = $current_case.findItemSetByName(values["item_set_name"])
	if !item_set.nil?
		title = "Add to existing item set?"
		message = "An item set with that name already exists. Do you wish to add to it?"
		if CommonDialogs.getConfirmation(message,title) != true
			next false
		end
	end

	# Confirm batch name is not blank
	if values["batch_name"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Batch Name'")
		next false
	end

	if !item_set.nil?
		existing_batches = item_set.getBatches
		if existing_batches.any?{|b|b.getName == values["batch_name"]}
			CommonDialogs.showWarning("A batch with the name provided already exists in the item set.  Please choose another batch name.")
			next false
		end
	end

	if values["record_digest_input"] && values["digest_input_field"].strip.empty?
		CommonDialogs.showWarning("Please provide a field name for recording digest input value.")
		next false
	end

	if values["record_digest"] && values["digest_field"].strip.empty?
		CommonDialogs.showWarning("Please provide a field name for recording digest value.")
		next false
	end

	next true
end

dialog.display
if dialog.getDialogResult == true
	values = dialog.toMap
	iutil = $utilities.getItemUtility
	modified_time_property_name = "File Modified"

	include_name = values["include_name"]
	include_file_size = values["include_file_size"]
	include_file_modified = values["include_file_modified"]
	include_item_date = values["include_item_date"]
	include_content_text = values["include_content_text"]

	by_family = values["by_family"]
	pull_in_families = values["pull_in_families"]

	record_digest_input = values["record_digest_input"]
	digest_input_field = values["digest_input_field"]
	record_digest = values["record_digest"]
	digest_field = values["digest_field"]

	date_format = nil
	date_format = "yyyyMMddHHmmssSSS" if values["accuracy_millisecond"]
	date_format = "yyyyMMddHHmmss" if values["accuracy_second"]
	date_format = "yyyyMMddHHmm" if values["accuracy_minute"]

	java_import org.joda.time.DateTimeZone
	investigation_time_zone = DateTimeZone.forID($current_case.getInvestigationTimeZone)

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Light Index Dedupe")
		pd.setAbortButtonVisible(false)

		pd.logMessage("Item Set Name: #{values["item_set_name"]}")
		pd.logMessage("Batch Name: #{values["batch_name"]}")

		pd.logMessage("Selected Items: #{$current_selected_items.size}")
		pd.logMessage("Pull in Family Members of Selected Items: #{pull_in_families}")
		
		if pull_in_families
			pd.setMainStatusAndLogIt("Resolving selection to items and descendants...")
			items = iutil.findItemsAndDescendants($current_selected_items)
			pd.logMessage("Resolved to #{items.size} items")
		else
			items = $current_selected_items
		end

		pd.logMessage("Deduplicate by Family: #{by_family}")

		pd.setMainStatusAndLogIt("Configuring settings...")
		semaphore = Mutex.new
		pd.setMainProgress(0,items.size)
		item_set_settings = {
			:batch => values["batch_name"],
		}

		# This defines the value we hand back to Nuix for a given item, the
		# value we return here is in turn used in place of MD5 for deduplication
		item_set_settings[:expression] = proc do |item|
			key_item = item
			if by_family
				key_item = item.getTopLevelItem
			end

			if key_item.nil?
				key_item = item
			end

			pieces = []
			if include_name
				pieces << key_item.getLocalisedName
			end

			if include_file_size
				file_size = key_item.getFileSize
	 			file_size = "" if file_size.nil?
	 			pieces << file_size.to_s
			end

			if include_file_modified
				modified_time = key_item.getProperties[modified_time_property_name]
				# Make sure we are using investigator time zone
				modified_time = modified_time.withZone(investigation_time_zone)
	 			if modified_time.nil?
	 				modified_time = ""
	 			else
	 				modified_time = modified_time.toString(date_format)
	 			end
	 			pieces << modified_time
			end

			if include_item_date
				item_date = key_item.getDate
				# Make sure we are using investigator time zone
				item_date = item_date.withZone(investigation_time_zone)
	 			if item_date.nil?
	 				item_date = ""
	 			else
	 				item_date = item_date.toString(date_format)
	 			end
	 			pieces << item_date
			end

			if include_content_text
				cleaned_text = key_item.getTextObject.toString
				cleaned_text = cleaned_text.gsub(/\s/,"")
				pieces << cleaned_text
			end
	 		
	 		result = pieces.join
	 		cm = nil
	 		if record_digest_input || record_digest
		 		cm = item.getCustomMetadata
		 		if record_digest_input
		 			cm[digest_input_field] = result
		 		end
		 	end

	 		if result.strip.empty?
	 			next nil
	 		else
	 			md5 = Digest::MD5.hexdigest(result)
	 			if record_digest
	 				cm[digest_field] = md5
	 			end
	 			next md5
	 		end
		end

		# === PROGRESS REPORTING ===
		current_stage_name = nil
		last_progress = Time.now
		item_set_settings[:progress] = proc do |info|
			semaphore.synchronize {
				if (Time.now - last_progress) > 0.5
					if current_stage_name != info.getStage
						current_stage_name = info.getStage
						pd.logMessage("Stage: #{current_stage_name}")
					end

					pd.setMainStatus("#{info.getStage} #{info.getStageCount}/#{items.size}")
					pd.setMainProgress(info.getStageCount)
					last_progress = Time.now
				end
			}
		end

		# === ADD TO ITEM SET ===
		item_set = $current_case.findItemSetByName(values["item_set_name"])
		if item_set.nil?
			pd.setMainStatusAndLogIt("Creating new item set...")
			item_set = $current_case.create_item_set(values["item_set_name"], {:deduplication => "Scripted"})
		else
			pd.setMainStatusAndLogIt("Using existing item set...")
		end

		pd.setMainStatusAndLogIt("Adding items to item set...")
		item_set.addItems(items, item_set_settings)

		pd.setCompleted
	end
end