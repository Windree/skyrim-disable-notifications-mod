#!/bin/bash

MODULE_CONFIG=$(
	cat <<'CONFIG'
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:noNamespaceSchemaLocation="http://qconsulting.ca/fo3/ModConfig5.0.xsd">
	<moduleName>Disable Notification Messages</moduleName>
	<installSteps order="Explicit">
		<installStep name="Options">
			<optionalFileGroups order="Explicit">
				<group name="Choose notification messages to disable" type="SelectExactlyOne">
					<plugins order="Explicit">
%PLUGINS%
					</plugins>
				</group>
			</optionalFileGroups>
		</installStep>
	</installSteps>
</config>
CONFIG
)

MODULE_PLUGIN=$(
	cat <<'PLUGIN'
<plugin name="%TITLE%">
    <description><![CDATA[
%DESCRIPTION_HEADER%:
%DESCRIPTION%
]]></description>
    <files>
        <file source="%NAME%\NotificationFilter.ini" destination="SKSE\Plugins\NotificationFilter.ini" priority="1" /> 
    </files>
    <typeDescriptor>
        <type name="%TYPE%" />
    </typeDescriptor>
</plugin>
PLUGIN
)
