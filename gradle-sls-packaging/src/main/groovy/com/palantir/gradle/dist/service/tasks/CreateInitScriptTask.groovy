/*
 * Copyright 2016 Palantir Technologies
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * <http://www.apache.org/licenses/LICENSE-2.0>
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.palantir.gradle.dist.service.tasks

import com.palantir.gradle.dist.service.JavaServiceDistributionPlugin
import com.palantir.gradle.dist.service.util.EmitFiles
import org.gradle.api.DefaultTask
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.Optional
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction

class CreateInitScriptTask extends DefaultTask {

    @Input
    String serviceName

    @Input
    @Optional
    String sidecarInitScript

    CreateInitScriptTask() {
        group = JavaServiceDistributionPlugin.GROUP_NAME
        description = "Generates daemonizing init.sh script."
    }

    @OutputFile
    File getOutputFile(String filename) {
        return new File("${project.buildDir}/scripts/${filename}")
    }

    @TaskAction
    void createInitScripts() {
        if (sidecarInitScript == null) {
            emitServiceInitScript('init.sh')
        } else {
            emitServiceInitScript('init_service.sh')
            emitMasterInitScript()
        }
    }

    void emitMasterInitScript() {
        EmitFiles.replaceVars(
                JavaServiceDistributionPlugin.class.getResourceAsStream('/init_master.sh'),
                getOutputFile('init.sh').toPath(),
                ['@sidecarInitScript@': project.property('sidecarInitScript').toString()])
                .toFile()
                .setExecutable(true)
    }

    void emitServiceInitScript(String targetFilename) {
        EmitFiles.replaceVars(
                JavaServiceDistributionPlugin.class.getResourceAsStream('/init_service.sh'),
                getOutputFile(targetFilename).toPath(),
                ['@serviceName@': serviceName, '@initScript@': targetFilename])
                .toFile()
                .setExecutable(true)
    }

    void configure(String serviceName, String sidecarInitScript) {
        this.serviceName = serviceName
        this.sidecarInitScript = sidecarInitScript
    }
}
