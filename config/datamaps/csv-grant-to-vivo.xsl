<!--
  Copyright (c) 2010 Christopher Haines, James Pence, Dale Scheppler, Nicholas Skaggs, Stephen V. Williams.
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the new BSD license
  which accompanies this distribution, and is available at
  http://www.opensource.org/licenses/bsd-license.html
  
  Contributors:
      Christopher Haines, Dale Scheppler, Nicholas Skaggs, Stephen V. Williams - initial API and implementation
      James Pence
-->
<!-- Header information for the Style Sheet
	The style sheet requires xmlns for each prefix you use in constructing
	the new elements
-->

<xsl:stylesheet version="2.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:core="http://vivoweb.org/ontology/core#"
	xmlns:score='http://vivoweb.org/ontology/score#'
	xmlns:rdfs='http://www.w3.org/2000/01/rdf-schema#'
	xmlns:db-csv='nullfields/csv/'>
	
	<xsl:output method="xml" indent="yes"/>
	<xsl:variable name="baseURI">http://vivoweb.org/harvest/csvfile/</xsl:variable>
	
	<xsl:template match="rdf:RDF">
		<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    		xmlns:core="http://vivoweb.org/ontology/core#"
    		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    		xmlns:score='http://vivoweb.org/ontology/score#'>
			<xsl:apply-templates select="rdf:Description" />		
		</rdf:RDF>
	</xsl:template>
	
	<xsl:template match="rdf:Description">
		<xsl:variable name="this" select="." />
		<xsl:call-template name="t_Grant">
		  <xsl:with-param name="this" select="$this" />
          <xsl:with-param name="grantid" select="$this/db-csv:GRANTID" />
		</xsl:call-template>
	</xsl:template>
		
	<xsl:template name="t_Grant">
		<xsl:param name='grantid' />
		<xsl:param name='this' />
		
		<!-- Setting dates for Grant -->
	        <xsl:variable name="startDate">           
	            <xsl:analyze-string select="$this/db-csv:STARTDATE" regex="^(....-..-..).*?$">
	                <xsl:matching-substring><xsl:value-of select="regex-group(1)"/></xsl:matching-substring>
	            </xsl:analyze-string>
	        </xsl:variable>

	        <xsl:variable name="endDate">           
	            <xsl:analyze-string select="$this/db-csv:ENDDATE" regex="^(....-..-..).*?$">
	                <xsl:matching-substring><xsl:value-of select="regex-group(1)"/></xsl:matching-substring>
	            </xsl:analyze-string>
	        </xsl:variable>
        
<!--	Creating a Grant-->
		<rdf:Description rdf:about="{$baseURI}grant/grant{$grantid}">
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#Grant"/>
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#Relationship"/>
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#Agreement"/>
			<score:grantID><xsl:value-of select="$grantid" /></score:grantID>
            <xsl:if test="not( $this/db-csv:GRANTNAME = '' or $this/db-csv:GRANTNAME = 'null' )">
            <rdfs:label><xsl:value-of select="$this/db-csv:GRANTNAME"/></rdfs:label>
            </xsl:if>
            <xsl:if test="not( $this/db-csv:ADMINDEPARTMENTID = '' or $this/db-csv:ADMINDEPARTMENTID = 'null' )">
			<core:administeredBy>
<!--			Creating a department to match with or a stub if no match-->
				<rdf:Description rdf:about="{$baseURI}org/org{$this/db-csv:ADMINDEPARTMENTID}">
					<score:deptID><xsl:value-of select="$this/db-csv:ADMINDEPARTMENTID"/></score:deptID>
					<rdfs:label><xsl:value-of select="$this/db-csv:ADMINDEPTNAME"/></rdfs:label>
					<core:administers rdf:resource="{$baseURI}grant/grant{$grantid}" />
					<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Organization"/>
				</rdf:Description>
			</core:administeredBy>
			</xsl:if>
            <xsl:if test="not( $this/db-csv:AMOUNT = '' or $this/db-csv:AMOUNT = 'null' )">
			<core:totalAwardAmount><xsl:value-of select="$this/db-csv:AMOUNT"/></core:totalAwardAmount>
			</xsl:if>
			
            <xsl:if test="not( $this/db-csv:SPONAWARDID = '' or $this/db-csv:SPONAWARDID = 'null' )">
            <core:sponsorAwardId><xsl:value-of select="$this/db-csv:SPONAWARDID"/></core:sponsorAwardId>
            </xsl:if>
			
			<xsl:choose>
				<xsl:when test="string($this/db-csv:FLOWTHRUORG) = '' or string($this/db-csv:FLOWTHRUORG) = 'null' "> 
                    <xsl:if test="not( $this/db-csv:AWARDINGORG = '' or $this/db-csv:AWARDINGORG = 'null' )">             
					<core:grantAwardedBy>
						<rdf:Description rdf:about="{$baseURI}sponsor/sponsor{$this/db-csv:AwardingOrgID}For{$grantid}">
							<rdfs:label><xsl:value-of select="$this/db-csv:AWARDINGORG"/></rdfs:label>
                            <score:orgID><xsl:value-of select="$this/db-csv:AWARDINGORGID"/></score:orgID>
							<core:awardsGrant rdf:resource="{$baseURI}grant/grant{$grantid}"/>
							<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Organization"/>
						</rdf:Description>
					</core:grantAwardedBy>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
				    <xsl:if test="not( $this/db-csv:AWARDINGORG = '' or $this/db-csv:AWARDINGORG = 'null' )">
					<core:grantSubcontractedThrough>
						<rdf:Description rdf:about="{$baseURI}sponsor/sponsor{$this/db-csv:AWARDINGORGID}For{$grantid}">
							<rdfs:label><xsl:value-of select="$this/db-csv:AWARDINGORG"/></rdfs:label>
                            <score:orgID><xsl:value-of select="$this/db-csv:AWARDINGORGID"/></score:orgID>
							<core:subcontractsGrant rdf:resource="{$baseURI}grant/grant{$grantid}"/>
							<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Organization"/>
						</rdf:Description>
					</core:grantSubcontractedThrough>
					<core:grantAwardedBy>
						<rdf:Description rdf:about="{$baseURI}sponsor/sponsor{$this/db-csv:FLOWTHRUORGID}For{$grantid}">
							<rdfs:label><xsl:value-of select="$this/db-csv:FLOWTHRUORG"/></rdfs:label>
                            <score:orgID><xsl:value-of select="$this/db-csv:FLOWTHRUORGID"/></score:orgID>
							<core:awardsGrant rdf:resource="{$baseURI}grant/grant{$grantid}"/>
							<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Organization"/>
						</rdf:Description>
					</core:grantAwardedBy>
					</xsl:if>
				</xsl:otherwise>
			</xsl:choose>
            <core:dateTimeInterval rdf:resource="{$baseURI}timeInterval/start{$startDate}ToEnd{$endDate}" />
        </rdf:Description>
        
         <rdf:Description rdf:about="{$baseURI}timeInterval/start{$startDate}ToEnd{$endDate}">
             <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Thing"/>
             <rdf:type rdf:resource="http://vivoweb.org/ontology/core#DateTimeInterval"/>
             <core:start rdf:resource="{$baseURI}timeInterval/date{$startDate}"/>
             <core:end rdf:resource="{$baseURI}timeInterval/date{$endDate}"/>
         </rdf:Description>
         
         <xsl:if test="not( $this/db-csv:STARTDATE = '' or $this/db-csv:STARTDATE = 'null' )">
         <rdf:Description rdf:about="{$baseURI}timeInterval/date{$startDate}">
             <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Thing"/>
             <rdf:type rdf:resource="http://vivoweb.org/ontology/core#DateTimeValue"/>
             <core:dateTimePrecision rdf:resource="http://vivoweb.org/ontology/core#yearMonthDayPrecision"/>
             <core:dateTime rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime"><xsl:value-of select="$this/db-csv:STARTDATE"/>T00:00:00</core:dateTime>
         </rdf:Description>
         </xsl:if>
                  
         <xsl:if test="not( $this/db-csv:ENDDATE = '' or $this/db-csv:ENDDATE = 'null' )">
         <rdf:Description rdf:about="{$baseURI}timeInterval/date{$endDate}">
             <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Thing"/>
             <rdf:type rdf:resource="http://vivoweb.org/ontology/core#DateTimeValue"/>
             <core:dateTimePrecision rdf:resource="http://vivoweb.org/ontology/core#yearMonthDayPrecision"/>
             <core:dateTime rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime"><xsl:value-of select="$this/db-csv:ENDDATE"/>T00:00:00</core:dateTime>
         </rdf:Description>
         </xsl:if>
         
		<xsl:if test="not( $this/db-csv:PIID = '' or $this/db-csv:PIID = 'null' )">
		<!--            Creating the PI-->
			<rdf:Description rdf:about="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:PIID}">
				<rdf:type rdf:resource="http://vivoweb.org/ontology/core#PrincipalInvestigatorRole"/>
				<rdf:type rdf:resource="http://vivoweb.org/ontology/core#InvestigatorRole"/>
				<rdf:type rdf:resource="http://vivoweb.org/ontology/core#ResearcherRole"/>
				<core:roleIn>
				    <rdf:Description rdf:about="{$baseURI}grant/grant{$grantid}">
				          <core:relatedRole rdf:resource="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:PIID}"/>
				    </rdf:Description>
				</core:roleIn>
		         <core:principalInvestigatorRoleOf>
		              <rdf:Description rdf:about="{$baseURI}person/person{$this/db-csv:PIID}">
							<rdf:type rdf:resource="http://vivoweb.org/harvester/excludeEntity" />
							<score:personID><xsl:value-of select="$this/db-csv:PIID"/></score:personID>
							<xsl:if test="not( $this/db-csv:NAMEPI = '' or $this/db-csv:NAMEPI = 'null' )">
                                <rdfs:label><xsl:value-of select="$this/db-csv:NAMEPI"/></rdfs:label>
                            </xsl:if>
							<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Person"/>
							<core:hasPrincipalInvestigatorRole rdf:resource="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:PIID}"/>
		              </rdf:Description>
		         </core:principalInvestigatorRoleOf>
			</rdf:Description>
		</xsl:if>
		<xsl:if test="not( $this/db-csv:COPIID = '' or $this/db-csv:COPIID = 'null' )">
		<!--            Creating the CoPI-->
			<rdf:Description rdf:about="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:COPIID}">
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#PrincipalInvestigatorRole"/>
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#InvestigatorRole"/>
			<rdf:type rdf:resource="http://vivoweb.org/ontology/core#ResearcherRole"/>
			<core:roleIn>
			    <rdf:Description rdf:about="{$baseURI}grant/grant{$grantid}">
			       <core:relatedRole rdf:resource="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:COPIID}"/>
			    </rdf:Description>
			</core:roleIn>
			<core:co-PrincipalInvestigatorRoleOf>
				<rdf:Description rdf:about="{$baseURI}person/person{$this/db-csv:COPIID}">
					<rdf:type rdf:resource="http://vivoweb.org/harvester/excludeEntity" />
					<score:personID><xsl:value-of select="$this/db-csv:COPIID"/></score:personID>
                       <xsl:if test="not( $this/db-csv:NAMECOPI = '' or $this/db-csv:NAMECOPI = 'null' )">
                           <rdfs:label><xsl:value-of select="$this/db-csv:NAMECOPI"/></rdfs:label>
                       </xsl:if>
					<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Person"/>
					<core:hasCo-PrincipalInvestigatorRole rdf:resource="{$baseURI}piRole/inGrant{$grantid}For{$this/db-csv:COPIID}"/>
				</rdf:Description>
			</core:co-PrincipalInvestigatorRoleOf>
		    </rdf:Description>
		</xsl:if>
	</xsl:template>
	
</xsl:stylesheet>