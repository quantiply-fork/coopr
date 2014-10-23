/*
 * Copyright © 2012-2014 Cask Data, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package co.cask.coopr.shell.command;

import org.junit.Test;
import org.mockito.Mockito;

/**
 * {@link co.cask.coopr.shell.command.DeleteProviderTypeResourcesCommand} class test.
 */
public class DeleteProviderTypeResourcesCommandTest extends AbstractTest {

  private static final String INPUT =
    String.format("delete resource-type %s with name %s version %s from provider %s",
                  TEST_RESOURCE_TYPE, TEST_RESOURCE_NAME, TEST_RESOURCE_VERSION, TEST_PLUGIN_TYPE);

  @Test
  public void testExecute() throws Exception {
    CLI.execute(INPUT, System.out);
    Mockito.verify(PLUGIN_CLIENT).deleteProviderTypeResourceVersion(Mockito.eq(TEST_PLUGIN_TYPE),
                                                                    Mockito.eq(TEST_RESOURCE_TYPE),
                                                                    Mockito.eq(TEST_RESOURCE_NAME),
                                                                    Mockito.eq(TEST_RESOURCE_VERSION));
  }
}
